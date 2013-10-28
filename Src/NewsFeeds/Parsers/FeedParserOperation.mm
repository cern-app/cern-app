//
//  FeedParserOperation.m
//  CERN
//
//  Created by Timur Pocheptsov on 6/4/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import "FeedParserOperation.h"

@implementation FeedParserOperation {
   MWFeedParser *feedParser;
   NSMutableArray *feedItems;
   MWFeedInfo *feedInfo;
}

@synthesize delegate;

//________________________________________________________________________________________
- (id) initWithFeedURLString : (NSString *) urlString
{
   assert(urlString != nil && "initWithFeedURLString, parameter 'urlString' is nil");

   if (self = [super init]) {
      NSURL * const url = [NSURL URLWithString : urlString];
      assert(url != nil && "initWithFeedURLString:, invalid url");

      feedParser = [[MWFeedParser alloc] initWithFeedURL : url];
      feedParser.feedParseType = ParseTypeFull;
      feedParser.connectionType = ConnectionTypeSynchronously;//We're already working in a background thread.
      feedParser.delegate = self;

      feedItems = [[NSMutableArray alloc] init];

      delegate = nil;
   }
   
   return self;
}

//________________________________________________________________________________________
- (void) main
{
   assert(feedParser != nil && "main, feedParser is nil");
   assert(feedItems != nil && "main, feedItems is nil");
   
   if (!self.isCancelled) {
      @autoreleasepool {//TODO: check this, do I really need a pool?
         [feedParser parse];
      }
   }
}

#pragma mark - MWFeedParser delegate.

//________________________________________________________________________________________
- (void) feedParser : (MWFeedParser *) parser didParseFeedInfo : (MWFeedInfo *) aFeedInfo
{
   assert(parser != nil && "feedParser:didParseFeedInfo:, parameter 'parser' is nil");
   assert(aFeedInfo != nil && "feedParser:didParseFeedInfo:, parameter 'aFeedInfo' is nil");
   
   feedInfo = aFeedInfo;
}

//________________________________________________________________________________________
- (void) feedParser : (MWFeedParser *) parser didParseFeedItem : (MWFeedItem *) item
{
   assert(parser != nil && "feedParser:didParseFeedItem:, parameter 'parser' is nil");
   assert(item != nil && "feedParser:didParseFeedItem:, parameter 'item' is nil");
   assert(feedItems != nil && "feedParser:didParseFeedItem:, feedItems is nil");
   
   [feedItems addObject : item];
}

//________________________________________________________________________________________
- (void) feedParser : (MWFeedParser *) parser didFailWithError : (NSError *) error
{
   assert(parser != nil && "feedParser:didFailWithError:, parameter 'parser' is nil");

   [self performSelectorOnMainThread : @selector(parserDidFailWithError:) withObject : error waitUntilDone : NO];
}

//________________________________________________________________________________________
- (void) feedParserDidFinish : (MWFeedParser *) parser
{
#pragma unused(parser)

   [self performSelectorOnMainThread : @selector(parserDidFinish) withObject : nil waitUntilDone : NO];
}

//2. Complementary methods - to be executed on a main thread, performSelector is called from the delegate's methods.

//________________________________________________________________________________________
- (void)  parserDidFailWithError : (NSError *) error
{
   if (!self.isCancelled) {
      if (self.delegate)
         [self.delegate parserDidFailWithError : error];
   }
}

//________________________________________________________________________________________
- (void) parserDidFinish
{
   if (!self.isCancelled) {
      if (self.delegate) {
         NSIndexSet * const validItems = [feedItems indexesOfObjectsPassingTest : ^BOOL(id obj, NSUInteger idx, BOOL *stop) {
            return ((MWFeedItem *)obj).link != nil;
         }];
         
        if (validItems.count) {
            NSArray * const filtered = [feedItems objectsAtIndexes : validItems];
            NSArray * const sortedItems = [filtered sortedArrayUsingComparator :
                                          ^ NSComparisonResult(id a, id b)
                                           {
                                              const NSComparisonResult cmp = [((MWFeedItem *)a).date compare : ((MWFeedItem *)b).date];
                                              if (cmp == NSOrderedAscending)
                                                 return NSOrderedDescending;
                                              else if (cmp == NSOrderedDescending)
                                                 return NSOrderedAscending;
                                              return cmp;
                                           }
                                         ];
            [delegate parserDidFinishWithInfo : feedInfo items : sortedItems];
         } else
            [delegate parserDidFinishWithInfo : feedInfo items : @[]];
      }
   }
}

@end
