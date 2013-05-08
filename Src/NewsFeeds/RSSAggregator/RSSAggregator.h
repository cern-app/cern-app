//
//  RSSAggregator.h
//  CERN App
//
//  Created by Eamon Ford on 5/31/12.
//  Copyright (c) 2012 CERN. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "RSSFeed.h"

@class RSSAggregator;
@protocol RSSAggregatorDelegate <NSObject>

@optional

- (void) allFeedsDidLoadForAggregator : (RSSAggregator *) aggregator;
- (void) aggregator : (RSSAggregator *) aggregator didFailWithError : (NSString *) errorDescription;
- (void) lostConnection : (RSSAggregator *) aggregator;

@end

@interface RSSAggregator : NSObject<RSSFeedDelegate, NSURLConnectionDelegate>

- (void) clearAllFeeds;

@property (nonatomic, strong) NSMutableArray *feeds;
@property (nonatomic) __weak id<RSSAggregatorDelegate> delegate;
@property (nonatomic, strong) NSArray *allArticles;

@property (nonatomic, readonly) BOOL isLoadingData;

- (void) addFeed : (RSSFeed *) feed;
- (void) addFeedForURL : (NSURL *) url;
- (void) refreshAllFeeds;

- (RSSFeed *) feedForArticle : (MWFeedItem *) article;

- (bool) hasConnection;
- (void) stopAggregator;

@end