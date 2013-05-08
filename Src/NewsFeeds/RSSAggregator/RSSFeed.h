//
//  RSSFeed.h
//  CERN App
//
//  Created by Eamon Ford on 5/28/12.
//  Copyright (c) 2012 CERN. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MWFeedParser.h"

@class RSSFeed;

@protocol RSSFeedDelegate <NSObject>
@optional

- (void) feedDidLoad : (RSSFeed *) feed;
- (void) feed : (RSSFeed *) feed didFailWithError : (NSError *) error;

@end


@interface RSSFeed : NSObject <NSURLConnectionDelegate, MWFeedParserDelegate>

@property (nonatomic, strong) MWFeedParser *parser;
@property (nonatomic, strong) MWFeedInfo *info;
@property (nonatomic, strong) NSMutableArray *articles;
@property (nonatomic) __weak id<RSSFeedDelegate> delegate;

- (id)initWithFeedURL : (NSURL *) url;
- (void) refresh;

- (void) stopParsing;
- (void) releaseParser;

@end
