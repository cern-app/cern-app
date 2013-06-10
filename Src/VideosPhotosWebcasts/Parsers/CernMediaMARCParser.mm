// The initial version by Eamon Ford on 6/25/12.

//Modified by Timur Pocheptsov.
//
//Initially, CernMediaMARCParser was working in two
//steps:
//  1) asynchronously download xml file (this is done on a background thread);
//  2) do xml parsing on a main thread.
//

//While the first part is ok and does not affect UI-reponsiveness, unfortunately,
//it looks like the second step can be quite a heavy-weight operation
//and application becomes non-responsive. "This thing sucks!" ((c) D. Nukem.).
//Now I'm using NSOperation and NSOperationQueue for this task. As it's inconvenient
//to execute two steps (one implicitly in a background thread, created by NSURLConnection,
//the second implicitly in a background thread created by NSOperationQueue), I'm using
//synchronous NSURLConnection from NSOperation (well, anyway two background threads will
//be created for this single task :( ) and as data received the same operation does parsing (if not cancelled).

#import <cassert>

#import "NSDateFormatter+DateFromStringOfUnknownFormat.h"
#import "CernMediaMARCParser.h"

@implementation CernMediaMARCParser {
   NSString *currentResourceType;
   NSMutableDictionary *currentRecord;
   NSMutableString *currentUValue;
   NSString *currentDatafieldTag;
   NSString *currentSubfieldCode;
   BOOL foundSubfield;
   BOOL foundX;
   BOOL foundU;
   
   NSXMLParser *xmlParser;
}

@synthesize url, resourceTypes, delegate;

//________________________________________________________________________________________
- (id) init
{
   return self = [super init];
}

//________________________________________________________________________________________
- (void) parse
{
   assert(url != nil && "parse, url is nil");
   assert(resourceTypes != nil && "parser, resourceTypes is nil");
   
   NSURLRequest * const request = [NSURLRequest requestWithURL : url];
   assert(request != nil && "parse, invalid url");

   NSURLResponse *response = nil;
   NSError *error = nil;
   NSData * const receivedData = [NSURLConnection sendSynchronousRequest : request returningResponse : &response error : &error];
   if (receivedData && !error) {
      //
      xmlParser = [[NSXMLParser alloc] initWithData : receivedData];
      xmlParser.delegate = self;
      [xmlParser parse];
   } else {
      assert(delegate != nil && "parse, delegate is nil");
      [delegate parser : self didFailWithError : error];
   }
}

//________________________________________________________________________________________
- (void) stop
{
   if (xmlParser)
      [xmlParser abortParsing];
}

#pragma mark NSXMLParserDelegate methods

//________________________________________________________________________________________
- (void) parserDidStartDocument : (NSXMLParser *) parser
{
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
            const NSUInteger numResourceTypes = resourceTypes.count;
            if (numResourceTypes) {
               for (int i = 0; i < numResourceTypes; i++) {
                  if ([string isEqualToString : [resourceTypes objectAtIndex : i]]) {
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
         assert(delegate != nil && "parser:didEndElement:namespaceURI:qualifiedName:, delegate is nil");
         [delegate parser : self didParseRecord : currentRecord];
      }
      currentRecord = nil;
   }
}

//________________________________________________________________________________________
- (void) parserDidEndDocument : (NSXMLParser *) parser
{
#pragma unused(parser)

   assert(delegate != nil && "parserDidEndDocument:, delegate is nil");
   [delegate parserDidFinish : self];
}

@end
