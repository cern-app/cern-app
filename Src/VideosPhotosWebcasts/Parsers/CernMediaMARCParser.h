//
//  CernMediaMODSParser.h
//  CERN App
//
//  Created by Eamon Ford on 6/25/12.
//  Copyright (c) 2012 CERN. All rights reserved.
//

#import <Foundation/Foundation.h>


@class CernMediaMARCParser;

@protocol CernMediaMarcParserDelegate <NSObject>

@optional
- (void)parser:(CernMediaMARCParser *)parser didParseRecord:(NSDictionary *)record;
- (void)parserDidFinish:(CernMediaMARCParser *)parser;
- (void)parser:(CernMediaMARCParser *)parser didFailWithError:(NSError *)error;
@end

@interface CernMediaMARCParser : NSObject<NSURLConnectionDelegate, NSXMLParserDelegate>

@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) NSArray *resourceTypes;
@property (nonatomic) __weak id<CernMediaMarcParserDelegate> delegate;
@property (nonatomic, assign) BOOL isFinishedParsing;

- (void) parse;
- (void) stop;

@end
