//
//  WebcastsParser.h
//  CERN App
//
//  Created by Eamon Ford on 8/16/12.
//  Copyright (c) 2012 CERN. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CernMediaMARCParser.h"

@class WebcastsParser;

@protocol WebcastsParserDelegate <NSObject>
@optional
- (void) webcastsParser : (WebcastsParser *) parser didParseRecentWebcast : (NSDictionary *) webcast;
- (void) webcastsParser : (WebcastsParser *) parser didParseUpcomingWebcast : (NSDictionary *) webcast;
- (void) webcastsParserDidFinishParsingRecentWebcasts : (WebcastsParser *) parser;
- (void) webcastsParserDidFinishParsingUpcomingWebcasts : (WebcastsParser *) parser;

- (void) webcastsParser : (WebcastsParser *) parser didFailWithError : (NSError *) error;
@end

@interface WebcastsParser : NSObject<NSURLConnectionDataDelegate, CernMediaMarcParserDelegate>

@property (weak) id<WebcastsParserDelegate> delegate;

@property (nonatomic, strong) NSMutableArray *recentWebcasts;
@property (nonatomic, strong) NSMutableArray *upcomingWebcasts;

@property (nonatomic, readonly) BOOL pendingRecentWebcastsParse;
@property (nonatomic, readonly) BOOL pendingUpcomingWebcastsParse;
@property (nonatomic, readonly) BOOL pendingHTMLStringLoad;

- (void) parseRecentWebcasts;
- (void) parseUpcomingWebcasts;
- (void) loadHTMLString;

//
- (void) stopParser;

@end
