//
//  CDSXMLParser.m
//  CERN
//
//  Created by Timur Pocheptsov on 10/2/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <cassert>

#import "CDSXMLParser.h"

//This parser will be created/executed by an operation object
//(so, it's in a background thread). The parser itself uses
//asynchronous connection == + 1 more thread (but according to
//the documentation even synchronous connections create additional threads).
//After xml data was downloaded, we parse it and pass the parsed data to
//the delegate (it will be an operation object).

@implementation CDSXMLParser {
   NSURLConnection *connection;
   NSMutableData *connectionData;
   NSXMLParser *xmlParser;
   NSMutableArray *CDSrecord;
   NSMutableDictionary *CDSDatafield;
   NSString *datafieldTag;
   NSString *subfieldCode;
   NSMutableString *elementData;
}

@synthesize CDSUrl, validFieldTags, validSubfieldCodes, delegate;

//________________________________________________________________________________________
- (id) init
{
   if (self = [super init]) {
      CDSUrl = nil;
      validFieldTags = nil;
      validSubfieldCodes = nil;
      delegate = nil;
      
      connection = nil;
      connectionData = nil;
      
      xmlParser = nil;
      CDSrecord = nil;
      datafieldTag = nil;
      subfieldCode = nil;
   }
   
   return self;
}

//________________________________________________________________________________________
- (BOOL) start
{
   assert(CDSUrl != nil && "start, CDSUrl is nil");
   assert(validFieldTags != nil && "start, validFieldTags is nil");
   assert(validSubfieldCodes != nil && "start, validSubfieldCodes is nil");
   
   //I assert on this condition instead of 'return NO;' - this parser MUST be started from an operation ONLY
   //and an operation CAN NEVER call the start twice (if the first one was successfull or stop was
   //not called between).
   assert(connection == nil && xmlParser == nil && "start, parser was started already");


   if (NSURL * const url = [NSURL URLWithString : CDSUrl]) {
      NSURLRequest * const urlRequest = [[NSURLRequest alloc] initWithURL : url];
      if (!urlRequest) {
         NSLog(@"error<CDSXMLParser>: start - failed to create an url request");
         return NO;
      }

      connectionData = [[NSMutableData alloc] init];
      if (!(connection = [[NSURLConnection alloc] initWithRequest : urlRequest delegate : self])) {
         connectionData = nil;
         NSLog(@"error<CDSXMLParser>: start - failed to create a connection");
         return NO;
      }
   } else {
      NSLog(@"error<CDSXMLParser>: start - failed to create url");
      return NO;
   }
   
   return YES;
}

//________________________________________________________________________________________
- (void) stop
{
   if (connection) {
      assert(xmlParser == nil && "stop, xmlParser working while connection is active");
      [connection cancel];
      connection = nil;
   } else if (xmlParser) {
      assert(connection == nil && "stop, xmlParser working while connection is active");
      [xmlParser abortParsing];
   }
}

#pragma mark - NSURLConnectionDataDelegate

//________________________________________________________________________________________
- (void) connection : (NSURLConnection *) aConnection didReceiveData : (NSData *) data
{
#pragma unused(aConnection)

   assert(data != nil && "connection:didReceieveData:, parameter 'data' is nil");
   assert(connectionData != nil && "connection:didReceiveData:, connectionData is nil");
   
   [connectionData appendData : data];
}

//________________________________________________________________________________________
- (void) connection : (NSURLConnection *) aConnection didFailWithError : (NSError *) error
{
#pragma unused(aConnection, error)

   connectionData = nil;
   connection = nil;
   //TODO: inform our delegate!
}

//________________________________________________________________________________________
- (void) connectionDidFinishLoading : (NSURLConnection *) aConnection
{
#pragma unused(aConnection)

   //Verify data? Start parsing.
}

#pragma mark - NSXMLParserDelegate

//________________________________________________________________________________________
- (void) parserDidStartDocument : (NSXMLParser *) parser
{
}

//________________________________________________________________________________________
- (void) parser : (NSXMLParser *) parser didStartElement : (NSString *) elementName namespaceURI : (NSString *) namespaceURI
         qualifiedName : (NSString *) qName attributes : (NSDictionary *) attributeDict
{
   if ([elementName isEqualToString : @"record"]) {
      assert(CDSrecord == nil &&
             "parser:didStartElement:namespaceURI:qualifiedName:attributes:, record already started");
      CDSrecord = [[NSMutableArray alloc] init];
   } else if ([elementName isEqualToString : @"datafield"]) {
      assert(datafieldTag == nil &&
             "parser:didStartElement:namespaceURI:qualifiedName:attributes:, datafield already started");
      datafieldTag = (NSString *)attributeDict[@"tag"];
      if ([validFieldTags member : datafieldTag]) {
         assert(CDSDatafield == nil &&
                "parser:didStartElement:namespaceURI:qualifiedName:attributes:, datafield already started");
         CDSDatafield = [[NSMutableDictionary alloc] init];
         [CDSDatafield setObject : datafieldTag forKey : @"tag"];
      } else
         datafieldTag = nil;
   } else if ([elementName isEqualToString : @"subfield"] && datafieldTag) {
      assert(subfieldCode == nil &&
             "parser:didStartElement:namespaceURI:qualifiedName:attributes:, subfield already started");
      subfieldCode = (NSString *)attributeDict[@"code"];
      if ([validSubfieldCodes member : subfieldCode]) {
         elementData = nil;
      } else
         subfieldCode = nil;
   }
}

//________________________________________________________________________________________
- (void) parser : (NSXMLParser *) parser foundCharacters : (NSString *) string
{
#pragma unused(parser)
   if (datafieldTag && subfieldCode) {
      if ([string stringByTrimmingCharactersInSet : [NSCharacterSet whitespaceAndNewlineCharacterSet]].length) {
         if (!elementData)
            elementData = [[NSMutableString alloc] initWithString : string];
         else
            [elementData appendString : string];
      }
   }
}

//________________________________________________________________________________________
- (void) parser : (NSXMLParser *) parser didEndElement : (NSString *) elementName namespaceURI : (NSString *) namespaceURI
         qualifiedName : (NSString *) qName
{
   if ([elementName isEqualToString : @"subfield"]) {
      if (subfieldCode) {
         assert(CDSDatafield != nil &&
                "parser:didEndElement:namespaceURI:, CDSDatafield is nil");
         [CDSDatafield setObject : elementData forKey : subfieldCode];
         subfieldCode = nil;
         elementData = nil;
      }
   } else if ([elementName isEqualToString : @"datafield"]) {
      if (datafieldTag) {
         assert(CDSrecord != nil &&
                "parser:didEndElement:namespaceURI:, CDSRecord is nil");
         [CDSrecord addObject : CDSDatafield];
         datafieldTag = nil;
         CDSDatafield = nil;
      }
   } else if ([elementName isEqualToString : @"record"]) {
      if (delegate && CDSrecord.count)
         [delegate parser : self didParseRecord : CDSrecord];
      CDSrecord = nil;
   }
}

//________________________________________________________________________________________
- (void) parserDidEndDocument : (NSXMLParser *) parser
{
   if (delegate)
      [delegate parserDidFinish : self];
}

@end
