//
//  MARCParserOperation.m
//  CERN
//
//  Created by Timur Pocheptsov on 6/10/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <cassert>

#import "MARCParserOperation.h"

@implementation MARCParserOperation {

   CernMediaMARCParser *parser;
}

@synthesize delegate;

//________________________________________________________________________________________
- (id) initWithURLString : (NSString *) urlString resourceTypes : (NSArray *) resourceTypes
{
   assert(urlString != nil && "initWithURLString:, parameter 'urlString' is nil");
   assert(resourceTypes != nil && "initWithURLString:, parameter 'resourceTypes' is nil");
   assert(resourceTypes.count > 0 && "initWithURLString:, parameter 'resourceType' is an empty array");
   
   if (self = [super init]) {
      parser = [[CernMediaMARCParser alloc] init];

      NSURL * const url = [NSURL URLWithString : urlString];
      assert(url != nil && "initWithURLString:, invalid url");
      parser.url = url;
      parser.resourceTypes = resourceTypes;
      parser.delegate = self;
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
         [parser parse];
      }
   }
}

#pragma mark - CernMediaMarcParserDelegate

//________________________________________________________________________________________
- (void) parser : (CernMediaMARCParser *) parser didParseRecord : (NSDictionary *) record
{
#pragma unused(parser, record)
   //NOOP.
}

//________________________________________________________________________________________
- (void) parserDidFinish : (CernMediaMARCParser *) parser
{
#pragma unused(parser)
   //NOOP.
}

//________________________________________________________________________________________
- (void) parser : (CernMediaMARCParser *) parser didFailWithError : (NSError *) error
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

@implementation VideoCollectionsParserOperation {
   NSMutableArray *videoMetadata;
}

//________________________________________________________________________________________
- (id) initWithURLString : (NSString *) urlString resourceTypes : (NSArray *) resourceTypes
{
   assert(urlString != nil && "initWithURLString:, parameter 'urlString' is nil");
   assert(resourceTypes != nil && "initWithURLString:, parameter 'resourceTypes' is nil");
   assert(resourceTypes.count > 0 && "initWithURLString:, parameter 'resourceType' is an empty array");

   if (self = [super initWithURLString:urlString resourceTypes:resourceTypes]) {
      videoMetadata = [[NSMutableArray alloc] init];
   }

   return self;
}

//________________________________________________________________________________________
- (void) parser : (CernMediaMARCParser *) aParser didParseRecord : (NSDictionary *) record
{
#pragma unused(aParser)

   assert(record != nil && "parser:didParseRecord:, parameter 'record' is nil");
   assert(videoMetadata != nil && "parser:didParseRecord:, videoMetadata is nil");

   if (self.isCancelled)
      return;

   //Copy over just the title, the date, and the first url of each resource type
   NSMutableDictionary * const video = [NSMutableDictionary dictionary];
   [video setObject : record[@"title"] forKey : @"title"];
   NSDate * const date = (NSDate *)record[@"date"];
   if (date)
      [video setObject : date forKey : @"VideoMetadataPropertyDate"];

   NSDictionary * const resources = (NSDictionary *)record[@"resources"];
   NSArray *resourceTypes = [resources allKeys];
   for (NSString *currentResourceType in resourceTypes) {
      NSURL * const url = [resources[currentResourceType] objectAtIndex : 0];
      [video setObject : url forKey : currentResourceType];
   }
   
   [videoMetadata addObject : video];
}

//________________________________________________________________________________________
- (void) parserDidFinish : (CernMediaMARCParser *) parser
{
#pragma unused(parser)
   
   if (!self.isCancelled) {
      assert(self.delegate != nil && "parserDidFinish:, delegate is nil");
      assert(videoMetadata != nil && "parserDidFinish:, videoMetadata is nil");//Can be empty, but not nil!
      
      [self performSelectorOnMainThread : @selector(informDelegateAboutCompletionWithItems:) withObject : videoMetadata waitUntilDone : NO];
   }
}

@end
