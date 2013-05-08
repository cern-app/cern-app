//
//  RSSAggregator.m
//  CERN App
//
//  Created by Eamon Ford on 5/31/12.
//  Copyright (c) 2012 CERN. All rights reserved.
//

#import <cassert>

#import "RSSAggregator.h"
#import "Reachability.h"
#import "MWFeedItem.h"

@implementation RSSAggregator {
   NSUInteger feedLoadCount;
   NSUInteger feedFailCount;

   Reachability *internetReach;
}

@synthesize feeds, delegate, allArticles;

//________________________________________________________________________________________
- (void) reachabilityStatusChanged : (Reachability *) current
{
#pragma unused(current)

   using CernAPP::NetworkStatus;

   if (internetReach && [internetReach currentReachabilityStatus] == NetworkStatus::notReachable) {
      if (feedLoadCount) {
         //We were still loading, now let the delegate know
         //and process this error as it wants.
         [self stopAggregator];
         [self cancelLoading];

         if (delegate && [delegate respondsToSelector : @selector(lostConnection:)])
            [delegate lostConnection : self];
      }
   }
}

//________________________________________________________________________________________
- (BOOL) isLoadingData
{
   return feedLoadCount;
}

//________________________________________________________________________________________
- (id) init
{
   if (self = [super init]) {
      feeds = [NSMutableArray array];

      feedLoadCount = 0;
      feedFailCount = 0;
      
      [[NSNotificationCenter defaultCenter] addObserver : self selector : @selector(reachabilityStatusChanged:) name : CernAPP::reachabilityChangedNotification object : nil];
      internetReach = [Reachability reachabilityForInternetConnection];
      [internetReach startNotifier];
      [self reachabilityStatusChanged : internetReach];      
   }

   return self;
}

//________________________________________________________________________________________
- (void) dealloc
{
   [self stopAggregator];
   [self releaseParser];
   [internetReach stopNotifier];
   [[NSNotificationCenter defaultCenter] removeObserver : self];
}

//________________________________________________________________________________________
- (void) addFeed : (RSSFeed *) feed
{
   assert(feed != nil && "addFeed:, parameter 'feed' is nil");
   assert(feedLoadCount == 0 && "addFeed:, called while refreshing aggregator");

   feed.delegate = self;
   [feeds addObject : feed];
}

//________________________________________________________________________________________
- (void) addFeedForURL : (NSURL *) url
{
   assert(url != nil && "addFeedForURL:, parameter 'url' is nil");
   assert(feedLoadCount == 0 && "addFeedForURL:, called while refreshing aggregator");

   RSSFeed * const feed = [[RSSFeed alloc] initWithFeedURL : url];
   [self addFeed : feed];
}

//________________________________________________________________________________________
- (void) clearAllFeeds
{
   self.allArticles = nil;
}

//________________________________________________________________________________________
- (void) refreshAllFeeds
{
   // Only refresh all feeds if we are not already in the middle of a refresh
   
   if (!feedLoadCount) {
      feedFailCount = 0;
      feedLoadCount = feeds.count;

      for (RSSFeed *feed in self.feeds)
         [feed refresh];
   }
}

//________________________________________________________________________________________
- (RSSFeed *) feedForArticle : (MWFeedItem *) article
{
   assert(article != nil && "feedForArticle:, parameter 'article' is nil");
   assert(feeds && [feeds count] && "feedForArticle:, feeds is either nil or empty");

   for (RSSFeed *feed in feeds)
      if ([feed.articles containsObject : article])
         return feed;

   return nil;
}

#pragma mark - RSSFeedDelegate

//________________________________________________________________________________________
- (void) feedDidLoad : (RSSFeed *) feed
{
   assert(feedLoadCount != 0 && "feedDidLoad:, no feeds are loading");
   assert(feed != nil && "feedDidLoad:, parameter 'feed' is nil");

   //Keep the track of how many feeds have loaded after refreshAllFeeds
   //was called, and after all feeds have loaded, inform the delegate.

   if (--feedLoadCount == 0) {
      allArticles = [self aggregate];
      if (delegate && [delegate respondsToSelector : @selector(allFeedsDidLoadForAggregator:)])
         [delegate allFeedsDidLoadForAggregator : self];
   }
}

//________________________________________________________________________________________
- (void) feed : (RSSFeed *) feed didFailWithError : (NSError *)error
{
#pragma unused(feed, error)

   assert(feedLoadCount != 0 && "feed:didFailWithError:, no feeds were loading");
   assert(feedFailCount < feeds.count && "feed:didFailWithError:, number of failed loads > number of feeds");
   assert(feed != nil && "feed:didFailWithError:, parameter 'feed' is nil");

   ++feedFailCount;
   --feedLoadCount;
   //
   if (feedFailCount == feeds.count) {
      feedLoadCount = 0;
      //All feeds failed to load.
      if (delegate && [delegate respondsToSelector : @selector(aggregator:didFailWithError:)])
         [delegate aggregator : self didFailWithError : @"Network error"];//[error description]];//Error messages from MWFeedParser are bad.
      [self cancelLoading];
   } else if (!feedLoadCount) {
      //Even if some feed was not loaded, still, some feeds are ok.
      allArticles = [self aggregate];
      if (delegate && [delegate respondsToSelector : @selector(allFeedsDidLoadForAggregator:)])
         [delegate allFeedsDidLoadForAggregator : self];
   }
}

#pragma mark - Private helper methods

//________________________________________________________________________________________
- (NSArray *) aggregate
{
   NSMutableArray *aggregation = [NSMutableArray array];
   for (RSSFeed *feed in self.feeds)
      [aggregation addObjectsFromArray : feed.articles];

   //We always sort articles using dates, in the descending order.
   //User-code can do something else with this articles.
   NSArray *sortedItems = [aggregation sortedArrayUsingComparator:
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
   
   return sortedItems;
}

//________________________________________________________________________________________
- (void) cancelLoading
{
   feedLoadCount = 0;
   feedFailCount = 0;
}

//________________________________________________________________________________________
- (void) stopAggregator
{
   //This one is called when controller is deleted,
   //I do not care in what state we now.
   for (RSSFeed * feed in feeds)
      [feed stopParsing];
}

//________________________________________________________________________________________
- (void) releaseParser
{
   //This one is called when controller is deleted,
   //I do not care in what state we now.
   for (RSSFeed * feed in feeds)
      [feed releaseParser];
}

//________________________________________________________________________________________
- (bool) hasConnection
{
   return [internetReach currentReachabilityStatus] != CernAPP::NetworkStatus::notReachable;
}

@end
