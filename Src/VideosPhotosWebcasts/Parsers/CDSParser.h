//
//  CDSParser.h
//  CERN
//
//  Created by Timur Pocheptsov on 10/2/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <Foundation/Foundation.h>

namespace CernAPP {

//Datafield tags.
extern NSString * const CDStagMARC;
extern NSString * const CDStagTitle;
extern NSString * const CDStagTitleAlt;
extern NSString * const CDStagDate;

//Subfield codes.
extern NSString * const CDScodeURL;
extern NSString * const CDScodeContent;
extern NSString * const CDScodeDate;
extern NSString * const CDScodeTitle;

}

@class CDSParserOperation;

@interface CDSXMLParser : NSObject<NSXMLParserDelegate>

- (id) initWithXMLData : (NSData *) data operation : (CDSParserOperation *) operation;
- (void) start;
- (void) stop;

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

- (id) initWithXMLData : (NSData *) xmlData datafieldTags : (NSSet *) tags
       subfieldCodes : (NSSet *) codes;

//These methods to be overriden.
- (void) parser : (CDSXMLParser *) parser didParseRecord : (NSArray *) record;
- (void) parserDidFinish : (CDSXMLParser *) parser;
- (void) parser : (CDSXMLParser *) parser didFailWithError : (NSError *) error;

@property (nonatomic, weak) NSObject<CDSParserOperationDelegate> *delegate;

@end