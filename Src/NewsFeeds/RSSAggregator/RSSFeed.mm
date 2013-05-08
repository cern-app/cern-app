//
//  RSSFeed.m
//  CERN App
//
//  Created by Eamon Ford on 5/28/12.
//  Copyright (c) 2012 CERN. All rights reserved.
//

#import <cassert>

#import "RSSArticle.h"
#import "RSSFeed.h"


@implementation RSSFeed

@synthesize parser, info, articles, delegate;

//________________________________________________________________________________________
- (id) initWithFeedURL : (NSURL *) url
{
   assert(url != nil && "initWithFeedURL:, parameter 'url' is nil");

   if (self = [super init]) {
      parser = [[MWFeedParser alloc] initWithFeedURL : url];
      parser.feedParseType = ParseTypeFull;
      parser.connectionType = ConnectionTypeAsynchronously;
      parser.delegate = self;
      articles = [NSMutableArray array];
   }

   return self;
}

//________________________________________________________________________________________
- (void) dealloc
{
   if ([parser isParsing])
      [parser stopParsing];
   parser = nil;
}

//________________________________________________________________________________________
- (void) refresh
{
   articles = [NSMutableArray array];
   [parser parse];
}

#pragma mark - MWFeedParserDelegate.

//________________________________________________________________________________________
- (void) feedParser : (MWFeedParser *) parser didParseFeedInfo : (MWFeedInfo *) feedInfo
{
   info = feedInfo;
}

//________________________________________________________________________________________
- (void) feedParser : (MWFeedParser *)parser didParseFeedItem:(MWFeedItem *) item
{
   [articles addObject : item];
}

//________________________________________________________________________________________
- (void) feedParser : (MWFeedParser *) feedParser didFailWithError : (NSError *) error
{
   assert(feedParser != nil && "feedParser:didFailWithError:, parameter 'feedParser' is nil");
   (void) feedParser;
   
   if (delegate && [delegate respondsToSelector : @selector(feed:didFailWithError:)])
      [delegate feed: self didFailWithError : error];
}

//________________________________________________________________________________________
- (void) feedParserDidFinish : (MWFeedParser *) feedParser
{
   assert(feedParser != nil && "feedParserDidFinish:, parameter 'feedParser' is nil");
   (void) feedParser;

   if (delegate && [delegate respondsToSelector : @selector(feedDidLoad:)])
      [delegate feedDidLoad : self];
}

//________________________________________________________________________________________
- (void) stopParsing
{
   if ([parser isParsing])
      [parser stopParsing];
}

//________________________________________________________________________________________
- (void) releaseParser
{
   parser = nil;
}

@end
