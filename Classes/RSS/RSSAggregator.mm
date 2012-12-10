//
//  RSSAggregator.m
//  CERN App
//
//  Created by Eamon Ford on 5/31/12.
//  Copyright (c) 2012 CERN. All rights reserved.
//

#import <cassert>

#import "RSSAggregator.h"
#import "MWFeedItem.h"

@implementation RSSAggregator {
   NSUInteger feedLoadCount;
   NSUInteger feedFailCount;

   BOOL loadingImages;
   NSUInteger imageForArticle;
   NSMutableData *imageData;
   NSURLConnection *currentConnection;
}

@synthesize feeds, delegate, allArticles, firstImages;

//________________________________________________________________________________________
- (BOOL) isLoadingData
{
   return loadingImages || feedLoadCount;
}

//________________________________________________________________________________________
- (id) init
{
   if (self = [super init]) {
      firstImages = [[NSMutableArray alloc] init];
      feeds = [NSMutableArray array];

      feedLoadCount = 0;
      feedFailCount = 0;
      loadingImages = NO;
   }

   return self;
}

//________________________________________________________________________________________
- (void) addFeed : (RSSFeed *) feed
{
   assert(feed != nil && "addFeed:, parameter 'feed' is nil");
   assert(feedLoadCount == 0 && "addFeed:, called while refreshing aggregator");
   assert(loadingImages == NO && "addFeed:, called while loading images");

   feed.delegate = self;
   [feeds addObject : feed];
}

//________________________________________________________________________________________
- (void) addFeedForURL : (NSURL *) url
{
   assert(url != nil && "addFeedForURL:, parameter 'url' is nil");
   assert(feedLoadCount == 0 && "addFeedForURL:, called while refreshing aggregator");
   assert(loadingImages == NO && "addFeedForURL:, called while loading images");

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
   if (!feedLoadCount && !loadingImages) {
      [firstImages removeAllObjects];
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

   // Keep track of how many feeds have loaded after refreshAllFeeds was called, and after all feeds have loaded, inform the delegate.
   if (--feedLoadCount == 0) {

      allArticles = [self aggregate];
      loadingImages = YES;//Now we'll try to load images for feed items, but first:
      if (delegate && [delegate respondsToSelector : @selector(allFeedsDidLoadForAggregator:)])
         [delegate allFeedsDidLoadForAggregator : self];

      [self downloadAllFirstImages];
   }
}

//________________________________________________________________________________________
- (void) feed : (RSSFeed *) feed didFailWithError : (NSError *)error
{
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
         [delegate aggregator : self didFailWithError : error];
   } else if (!feedLoadCount)
      [self downloadAllFirstImages];
}

#pragma mark - Private helper methods

//________________________________________________________________________________________
- (UIImage *) firstImageForArticle : (MWFeedItem *) article
{
   const NSUInteger index = [allArticles indexOfObject : article];
   if (index != NSNotFound && index < [firstImages count])
      return [firstImages objectAtIndex : index];
   
   return nil;
}

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
- (void) downloadAllFirstImages
{
   assert(loadingImages == YES && "downloadAllFirstImages, can be called only while loading images");

   if (allArticles.count) {
      imageForArticle = 0;
      [self downloadFirstImageForNextArticle];
   }
}

//________________________________________________________________________________________
- (void) downloadFirstImageForNextArticle
{
   assert(imageForArticle < [allArticles count] &&
         "downloadFirstImageForNextArticle, imageForArticle is out of bounds");
   assert(loadingImages == YES && "downloadFirstImageForNextArticle, can be called only while loading images");

   MWFeedItem * const article = [allArticles objectAtIndex : imageForArticle];

   NSString *body = article.content;
   if (!body)
      body = article.summary;

   NSURL * const imageURL = [self firstImageURLFromHTMLString : body];
   if (imageURL) {
      imageData = [[NSMutableData alloc] init];
      NSURLRequest * const request = [NSURLRequest requestWithURL : imageURL];
      currentConnection = [[NSURLConnection alloc] initWithRequest : request delegate : self startImmediately : YES];
   } else if (imageForArticle + 1 == [allArticles count]) {
      loadingImages = NO;
      currentConnection = nil;
      imageData = nil;
   } else {
      ++imageForArticle;
      [self downloadFirstImageForNextArticle];
   }
}

//________________________________________________________________________________________
- (void) informDelegateOfFirstImage : (UIImage *) image downloadForArticle : (MWFeedItem *) article
{
   assert(loadingImages == YES &&
          "informDelegateOfFirstImage:downloadForArticle:, can be called only while loading images");
   assert(imageForArticle < [allArticles count] &&
          "informDelegateOfFirstImage:downloadForArticle:, imageForArticle is out of bounds");
   assert(image != nil &&
          "informDelegateOfFirstImage:downloadForArticle:, parameter 'image' is nil");
   assert(article != nil &&
          "informDelegateOfFirstImage:downloadForArticle:, parameter 'article' is nil");

   [self.delegate aggregator : self didDownloadFirstImage : image forArticle : article];
}

//________________________________________________________________________________________
- (NSURL *) firstImageURLFromHTMLString : (NSString *) htmlString
{
   if (!htmlString)
      return nil;


   NSScanner * const theScanner = [NSScanner scannerWithString : htmlString];
   //Find the start of IMG tag
   [theScanner scanUpToString : @"<img" intoString : nil];
   
   if (![theScanner isAtEnd]) {
      [theScanner scanUpToString : @"src" intoString : nil];
      NSCharacterSet * const charset = [NSCharacterSet characterSetWithCharactersInString : @"\"'"];
      [theScanner scanUpToCharactersFromSet : charset intoString : nil];
      [theScanner scanCharactersFromSet : charset intoString : nil];
      NSString *urlString = nil;
      [theScanner scanUpToCharactersFromSet : charset intoString : &urlString];
      // "url" now contains the URL of the img
      if (urlString)
         return [NSURL URLWithString : urlString];
   }

   // if no img url was found, return nil
   return nil;
}

#pragma mark - NSURLConnectionDelegate.

//________________________________________________________________________________________
- (void) connection : (NSURLConnection *) connection didReceiveData : (NSData *)data
{
   assert(data != nil && "connection:didReceiveData:, parameter 'data' is nil");
   assert(loadingImages == YES && "connection:didReceiveData:, can be called only while loading images");
   assert(imageData != nil && "connection:didReceiveData:, imageData is nil");
   
   [imageData appendData : data];
}

//________________________________________________________________________________________
- (void) connectionDidFinishLoading : (NSURLConnection *) urlConnection
{
   assert(loadingImages == YES &&
          "connectionDidFinishLoading:, can be called only while loading images");
   assert(imageData != nil &&
          "connectionDidFinishLoading:, imageData is nil");
   assert(imageForArticle < [allArticles count] &&
          "connectionDidFinishLoading:, imageForArticle is out of bounds");
   
   if ([imageData length]) {
      UIImage *firstImage = [[UIImage alloc] initWithData : imageData];

      if (firstImage) {
         [firstImages addObject : firstImage];
         MWFeedItem * const currentArticle = [allArticles objectAtIndex : imageForArticle];
         // Inform the delegate on the main thread that the image downloaded
         if (delegate && [delegate respondsToSelector : @selector(aggregator:didDownloadFirstImage:forArticle:)])
            [self informDelegateOfFirstImage : firstImage downloadForArticle : currentArticle];
      }

      if (imageForArticle + 1 == [allArticles count]) {
         //We stop
         loadingImages = NO;
         imageForArticle = 0;
         imageData = nil;
         currentConnection = nil;
      } else {
         ++imageForArticle;
         [self downloadFirstImageForNextArticle];
      }
   }
}

//________________________________________________________________________________________
- (void) connection : (NSURLConnection *) urlConnection didFailWithError : (NSError *) error
{
   assert(loadingImages == YES &&
          "connection:didFailWithError:, can be called only while loading images");
   assert(imageForArticle < [allArticles count] &&
          "connection:didFailWithError:, imageForArticle is out of bounds");
   
   if (imageForArticle + 1 == [allArticles count]) {
      //Stop.
      loadingImages = NO;
      imageForArticle = 0;
      imageData = nil;
      currentConnection = nil;
   } else {
      //Try to continue.
      ++imageForArticle;
      [self downloadFirstImageForNextArticle];
   }
}



@end
