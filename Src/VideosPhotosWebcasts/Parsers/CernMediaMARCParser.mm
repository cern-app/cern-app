//
//  CernMediaMODSParser.m
//  CERN App
//
//  Created by Eamon Ford on 6/25/12.
//  Copyright (c) 2012 CERN. All rights reserved.
//

#import "NSDateFormatter+DateFromStringOfUnknownFormat.h"
#import "CernMediaMARCParser.h"

@implementation CernMediaMARCParser {
   NSMutableData *asyncData;
   NSString *currentResourceType;
   NSMutableDictionary *currentRecord;
   NSMutableString *currentUValue;
   NSString *currentDatafieldTag;
   NSString *currentSubfieldCode;
   BOOL foundSubfield;
   BOOL foundX;
   BOOL foundU;
   
   NSURLConnection *currentConnection;
   NSXMLParser *xmlParser;
}

@synthesize isFinishedParsing;

//________________________________________________________________________________________
- (id) init
{
   if (self = [super init]) {
      asyncData = [[NSMutableData alloc] init];
      self.url = [[NSURL alloc] init];
      self.resourceTypes = [NSMutableArray array];
      isFinishedParsing = YES;
   }

   return self;
}

//________________________________________________________________________________________
- (void) dealloc
{
   [self stop];
}

//________________________________________________________________________________________
- (void) parse
{
   if (isFinishedParsing) {
      xmlParser = nil;
      isFinishedParsing = NO;
      NSURLRequest *request = [NSURLRequest requestWithURL : self.url];
      currentConnection = [NSURLConnection connectionWithRequest : request delegate : self];
   }
}

//________________________________________________________________________________________
- (void) stop
{
   //TODO: test!
   if (!isFinishedParsing) {
      if (currentConnection)
         [currentConnection cancel];
      currentConnection = nil;
      if (xmlParser)
         [xmlParser abortParsing];
      xmlParser = nil;
      isFinishedParsing = YES;
   }
}

#pragma mark NSURLConnectionDelegate methods

//________________________________________________________________________________________
- (void) connection : (NSURLConnection *) connection didReceiveData : (NSData *) data
{
   [asyncData appendData : data];
}

//________________________________________________________________________________________
- (void) connectionDidFinishLoading : (NSURLConnection *) connection
{
   currentConnection = nil;
   xmlParser = [[NSXMLParser alloc] initWithData : asyncData];
   xmlParser.delegate = self;
   [xmlParser parse];
}

//________________________________________________________________________________________
- (void) connection : (NSURLConnection *) connection didFailWithError : (NSError *) error
{
   if (self.delegate && [self.delegate respondsToSelector : @selector(parser:didFailWithError:)])
      [self.delegate parser : self didFailWithError : error];
   currentConnection = nil;

   isFinishedParsing = YES;//TODO: test!
}

#pragma mark NSXMLParserDelegate methods

//________________________________________________________________________________________
- (void) parserDidStartDocument : (NSXMLParser *) parser
{
   asyncData = [[NSMutableData alloc] init];
   currentUValue = [NSMutableString string];
}

//________________________________________________________________________________________
- (void) parser : (NSXMLParser *) parser didStartElement : (NSString *) elementName namespaceURI : (NSString *) namespaceURI
         qualifiedName : (NSString *) qualifiedName attributes : (NSDictionary *) attributeDict
{
   if ([elementName isEqualToString : @"record"]) {
      currentRecord = [NSMutableDictionary dictionary];
      [currentRecord setObject : [NSMutableDictionary dictionary] forKey : @"resources"];
   } else if ([elementName isEqualToString : @"datafield"]) {
      currentDatafieldTag = [attributeDict objectForKey : @"tag"];
      foundX = NO;
      foundU = NO;
      foundSubfield = NO;
      currentResourceType = @"";
   } else if ([elementName isEqualToString : @"subfield"]) {
      currentSubfieldCode = [attributeDict objectForKey : @"code"];
      if ([currentDatafieldTag isEqualToString : @"856"]) {
         if ([currentSubfieldCode isEqualToString : @"x"]) {
            foundSubfield = YES;
         } else if ([currentSubfieldCode isEqualToString : @"u"]) {
            [currentUValue setString : @""];
            foundSubfield = YES;
         }
      } else if ([currentDatafieldTag isEqualToString : @"245"]) {
         if ([currentSubfieldCode isEqualToString : @"a"]) {
            foundSubfield = YES;
         }
      } else if ([currentDatafieldTag isEqualToString : @"269"]) {
         if ([currentSubfieldCode isEqualToString : @"c"]) {
            foundSubfield = YES;
         }
      }
   }
}

// If we've found a resource type descriptor or a URL, we will have to hold it temporarily until
// we have exited the datafield, before we can assign it to the current record. If we've found
// the title however, we can assign it to the record immediately.

//________________________________________________________________________________________
- (void) parser : (NSXMLParser *) parser foundCharacters : (NSString *)string
{
   NSString *stringWithoutWhitespace = [string stringByTrimmingCharactersInSet : [NSCharacterSet whitespaceAndNewlineCharacterSet]];

   if (![stringWithoutWhitespace isEqualToString : @""]) {
      if (foundSubfield == YES) {
         if ([currentSubfieldCode isEqualToString : @"x"]) {
            // if the subfield has code="x", it will contain a resource type descriptor
            const NSUInteger numResourceTypes = self.resourceTypes.count;
            if (numResourceTypes) {
               for (int i = 0; i < numResourceTypes; i++) {
                  if ([string isEqualToString : [self.resourceTypes objectAtIndex : i]]) {
                     currentResourceType = string;
                     foundX = YES;
                     break;
                  }
               }
            } else {
               currentResourceType = string;
               foundX = YES;
            }
         } else if ([currentSubfieldCode isEqualToString : @"u"]) {
            // if the subfield has code="u", it will contain an url to the resource
            [currentUValue appendString : string];
            foundU = YES;
         } else if ([currentSubfieldCode isEqualToString : @"a"]) {
            if (NSString * const titleString = (NSString *)currentRecord[@"title"]) {
               [currentRecord setObject : [titleString stringByAppendingString : string] forKey : @"title"];
            } else {
               [currentRecord setObject : string forKey : @"title"];
            }
         } else if ([currentSubfieldCode isEqualToString : @"c"]) {
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            NSDate * date = [formatter dateFromStringOfUnknownFormat : string];
            if (date)
               [currentRecord setObject : date forKey : @"date"];
         }
      }
   }
}

//________________________________________________________________________________________
- (void) parser : (NSXMLParser *) parser didEndElement : (NSString *) elementName namespaceURI : (NSString *) namespaceURI qualifiedName : (NSString *) qName
{
   if ([elementName isEqualToString : @"datafield"]) {
      if (foundX && foundU) {
       // if there isn't already an array of URLs for the current x value in the current record, create one
         NSMutableDictionary * const resources = [currentRecord objectForKey : @"resources"];
         if (![resources objectForKey : currentResourceType]) {
            [resources setObject : [NSMutableArray array] forKey : currentResourceType];
         }

         NSURL *resourceURL = [NSURL URLWithString : [currentUValue stringByTrimmingCharactersInSet : [NSCharacterSet whitespaceAndNewlineCharacterSet]]];
         NSMutableArray *urls = [resources objectForKey : currentResourceType];
         // add the url we found into the appropriate url array
         [urls addObject : resourceURL];
      }
   } else if ([elementName isEqualToString : @"record"]) {
      if (((NSMutableDictionary *)[currentRecord objectForKey : @"resources"]).count) {
         if (self.delegate && [self.delegate respondsToSelector : @selector(parser:didParseRecord:)]) {
            [self.delegate parser : self didParseRecord:currentRecord];
         }
      }

      currentRecord = nil;
   }
}

//________________________________________________________________________________________
- (void) parserDidEndDocument : (NSXMLParser *) parser
{
   self.isFinishedParsing = YES;
   if (self.delegate && [self.delegate respondsToSelector : @selector(parserDidFinish:)])
      [self.delegate parserDidFinish : self];
}

@end
