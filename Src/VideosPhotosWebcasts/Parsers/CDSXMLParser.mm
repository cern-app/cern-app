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
}

@synthesize CDSUrl, delegate;

//________________________________________________________________________________________
- (BOOL) start
{
   assert(CDSUrl != nil && "start, CDSUrl is nil");
   
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
}

//________________________________________________________________________________________
- (void) parser : (NSXMLParser *) parser foundCharacters : (NSString *) string
{
}

//________________________________________________________________________________________
- (void) parser : (NSXMLParser *) parser didEndElement : (NSString *) elementName namespaceURI : (NSString *) namespaceURI
         qualifiedName : (NSString *) qName
{
}

//________________________________________________________________________________________
- (void) parserDidEndDocument : (NSXMLParser *) parser
{

}

@end
