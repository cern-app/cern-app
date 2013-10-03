//
//  CDSParser.m
//  CERN
//
//  Created by Timur Pocheptsov on 10/2/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <cassert>

#import "CDSParser.h"

//This parser will be created/executed by an operation object
//(so, it's in a background thread). The parser itself uses
//asynchronous connection == + 1 more thread (but according to
//the documentation even synchronous connections create additional threads).
//After xml data was downloaded, we parse it and pass the parsed data to
//the delegate (it will be an operation object).

@implementation CDSXMLParser {
   __weak CDSParserOperation *operation;
   NSURLConnection *connection;
   NSMutableData *connectionData;
   NSXMLParser *xmlParser;
   NSMutableArray *CDSrecord;
   NSMutableDictionary *CDSDatafield;
   NSString *datafieldTag;
   NSString *subfieldCode;
   NSMutableString *elementData;
}

@synthesize CDSUrl, validFieldTags, validSubfieldCodes;

//________________________________________________________________________________________
- (id) initWithOperation : (CDSParserOperation *) anOperation
{
   assert(anOperation != nil && "initWithOperation:, parameter 'anOperation' is nil");

   if (self = [super init]) {
      CDSUrl = nil;
      validFieldTags = nil;
      validSubfieldCodes = nil;
      operation = anOperation;
   
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
- (BOOL) stopIfCancelled
{
   if (operation.isCancelled)
      [self stop];

   return operation.isCancelled;
}

//________________________________________________________________________________________
- (BOOL) start
{
   assert(operation != nil && "start, operation is nil");
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
      xmlParser.delegate = nil;
   }
}

#pragma mark - NSURLConnectionDataDelegate

//________________________________________________________________________________________
- (void) connection : (NSURLConnection *) aConnection didReceiveData : (NSData *) data
{
#pragma unused(aConnection)

   if ([self stopIfCancelled])
      return;

   assert(data != nil && "connection:didReceieveData:, parameter 'data' is nil");
   assert(connectionData != nil && "connection:didReceiveData:, connectionData is nil");
   
   [connectionData appendData : data];
}

//________________________________________________________________________________________
- (void) connection : (NSURLConnection *) aConnection didFailWithError : (NSError *) error
{
#pragma unused(aConnection)

   if ([self stopIfCancelled])
      return;

   connectionData = nil;
   connection = nil;

   assert(operation != nil && "connection:didFailWithError:, operation is nil");
   [operation parser : self didFailWithError : error];
}

//________________________________________________________________________________________
- (void) connectionDidFinishLoading : (NSURLConnection *) aConnection
{
#pragma unused(aConnection)

   if ([self stopIfCancelled])
      return;

   //Verify data? Start parsing.
   if (connectionData.length) {
      assert(xmlParser == nil && "connectionDidFinishLoading:, xmlParser is active already");
      xmlParser = [[NSXMLParser alloc] initWithData : connectionData];
      xmlParser.delegate = self;
      [xmlParser parse];
   } else {
      assert(operation != nil && "connectionDidFinishLoading:, operation is nil");
      [operation parserDidFinish : self];
   }
}

#pragma mark - NSXMLParserDelegate

//________________________________________________________________________________________
- (void) parserDidStartDocument : (NSXMLParser *) parser
{
#pragma unused(parser)

   [self stopIfCancelled];
}

//________________________________________________________________________________________
- (void) parser : (NSXMLParser *) parser didStartElement : (NSString *) elementName namespaceURI : (NSString *) namespaceURI
         qualifiedName : (NSString *) qName attributes : (NSDictionary *) attributeDict
{
#pragma unused(parser, namespaceURI, qName)

   if ([self stopIfCancelled])
      return;

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

   if ([self stopIfCancelled])
      return;

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
#pragma unsued(parser, namespaceURI, qName)

   if ([self stopIfCancelled])
      return;

   if ([elementName isEqualToString : @"subfield"]) {
      if (subfieldCode) {
         assert(CDSDatafield != nil &&
                "parser:didEndElement:namespaceURI:qualifiedName:, CDSDatafield is nil");
         [CDSDatafield setObject : elementData forKey : subfieldCode];
         subfieldCode = nil;
         elementData = nil;
      }
   } else if ([elementName isEqualToString : @"datafield"]) {
      if (datafieldTag) {
         assert(CDSrecord != nil &&
                "parser:didEndElement:namespaceURI:qualifiedName:, CDSRecord is nil");
         [CDSrecord addObject : CDSDatafield];
         datafieldTag = nil;
         CDSDatafield = nil;
      }
   } else if ([elementName isEqualToString : @"record"]) {
      if (CDSrecord.count) {
         assert(operation != nil &&
                "parser:didEndElement:namespaceURI:qualifiedName:, operation is nil");
         [operation parser : self didParseRecord : CDSrecord];
      }

      CDSrecord = nil;
   }
}

//________________________________________________________________________________________
- (void) parserDidEndDocument : (NSXMLParser *) parser
{
#pragma unused(parser)

   if ([self stopIfCancelled])
      return;

   assert(operation != nil && "parserDidEndDocument:, operation is nil");
   [operation parserDidFinish : self];
}

@end

#pragma mark - Parser's wrapper - operation object.

@implementation CDSParserOperation {
   CDSXMLParser *parser;
}

@synthesize delegate;

//________________________________________________________________________________________
- (id) initWithURLString : (NSString *) urlString datafieldTags : (NSSet *) tags subfieldCodes : (NSSet *) codes
{
   assert(urlString != nil && "initWithURLString:datafieldTags:subfieldCodes:, parameter 'urlString' is nil");
   assert(tags != nil && "initWithURLString:datafieldTags:subfieldCodes:, parameter 'tags' is nil");
   assert(tags.count > 0 && "initWithURLString:datafieldTags:subfieldCodes:, parameter 'tags' is an empty set");
   assert(codes != nil && "initWithURLString:datafieldTags:subfieldCodes:, parameter 'codes' is nil");
   assert(codes.count > 0 && "initWithURLString:datafieldTags:subfieldCodes:, parameter 'codes' is an empty set");
   
   if (self = [super init]) {
      parser = [[CDSXMLParser alloc] initWithOperation : self];
      parser.CDSUrl = urlString;
      parser.validFieldTags = tags;
      parser.validSubfieldCodes = codes;
   }

   return self;
}

#pragma mark - NSOpetation.

//________________________________________________________________________________________
- (void) main
{
   assert(parser != nil && "main, parser is nil");
   
   if (!self.isCancelled) {
      @autoreleasepool {//TODO: check this, do I really need a pool?
         [parser start];
      }
   }
}

#pragma mark - Methods for CDSXMLParser to keeps us informed (and to be overriden by concrete operations).

//________________________________________________________________________________________
- (void) parser : (CDSXMLParser *) parser didParseRecord : (NSDictionary *) record
{
#pragma unused(parser, record)
   //NOOP.
}

//________________________________________________________________________________________
- (void) parserDidFinish : (CDSXMLParser *) parser
{
#pragma unused(parser)
   //NOOP.
}

//________________________________________________________________________________________
- (void) parser : (CDSXMLParser *) parser didFailWithError : (NSError *) error
{
#pragma unused(parser)
   [self performSelectorOnMainThread : @selector(informDelegateAboutError:) withObject : error waitUntilDone : NO];
}

#pragma mark - Aux. methods to be executed on a main thread (inform a delegate).

//________________________________________________________________________________________
- (void) informDelegateAboutError : (NSError *) error
{
   //I can assert here on something like [NSThread isMainThread]
   if (!self.isCancelled) {
      assert(delegate != nil && "informDelegateAboutError:, delegate is nil");
      [delegate parserDidFailWithError : error];
   }
}

//________________________________________________________________________________________
- (void) informDelegateAboutCompletionWithItems : (NSArray *) items
{
   //I can assert here on something like [NSThread isMainThread]
   assert(items != nil && "informDelegateAboutCompletionWithItems:, parameter 'items' is nil");

   if (!self.isCancelled) {
      assert(delegate != nil && "informDelegateAboutCompletionWithItems:, delegate is nil");
      [delegate parserDidFinishWithItems : items];
   }
}

@end
