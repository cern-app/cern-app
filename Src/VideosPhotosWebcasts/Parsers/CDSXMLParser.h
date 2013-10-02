//
//  CDSXMLParser.h
//  CERN
//
//  Created by Timur Pocheptsov on 10/2/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CDSXMLParser;

@protocol CDSXMLParserDelegate
@required
- (void) parser : (CDSXMLParser *) parser didParseRecord : (NSArray *) record;
- (void) parserDidFinish : (CDSXMLParser *) parser;
- (void) parser : (CDSXMLParser *) parser didFailWithError : (NSError *) error;
@end

@interface CDSXMLParser : NSObject<NSURLConnectionDataDelegate, NSXMLParserDelegate>

@property (nonatomic) NSString *CDSUrl;
@property (nonatomic) NSSet *validFieldTags;
@property (nonatomic) NSSet *validSubfieldCodes;
@property (nonatomic, weak) NSObject<CDSXMLParserDelegate> *delegate;

- (BOOL) start;
- (void) stop;

@end
