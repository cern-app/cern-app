//
//  CDSParser.h
//  CERN
//
//  Created by Timur Pocheptsov on 10/2/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CDSParserOperation;

@interface CDSXMLParser : NSObject<NSURLConnectionDataDelegate, NSXMLParserDelegate>

- (id) initWithOperation : (CDSParserOperation *) operation;
- (BOOL) start;
- (void) stop;

@property (nonatomic) NSString *CDSUrl;
@property (nonatomic) NSSet *validFieldTags;
@property (nonatomic) NSSet *validSubfieldCodes;

@end

//We parse CDS' xml in operations to use background threads,
//since xml parsing is extremely slow/expensive with Apple's frameworks.

//CDSXMLParser informs operation about its progress,
//when finished - operation informs its own delegate.
@protocol CDSParserOperationDelegate <NSObject>
//'error' parameter can be nil.
- (void) parserDidFailWithError : (NSError *) error;
//'items' can not be nil.
- (void) parserDidFinishWithItems : (NSArray *) items;
@end

//Base class for different parsing operations (videos, photos, whatever).
@interface CDSParserOperation : NSOperation

- (id) initWithURLString : (NSString *) urlString datafieldTags : (NSSet *) tags
       subfieldCodes : (NSSet *) codes;

//These methods to be overriden.
- (void) parser : (CDSXMLParser *) parser didParseRecord : (NSArray *) record;
- (void) parserDidFinish : (CDSXMLParser *) parser;
- (void) parser : (CDSXMLParser *) parser didFailWithError : (NSError *) error;

@property (nonatomic, weak) NSObject<CDSParserOperationDelegate> *delegate;

@end