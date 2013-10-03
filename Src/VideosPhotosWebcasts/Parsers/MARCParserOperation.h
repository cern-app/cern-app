//
//  MARCParserOperation.h
//  CERN
//
//  Created by Timur Pocheptsov on 6/10/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CernMediaMARCParser.h"


@protocol MARCParserOperationDelegate <NSObject>

//'error' parameter can be nil.
- (void) parserDidFailWithError : (NSError *) error;
//'items' can not be nil.
- (void) parserDidFinishWithItems : (NSArray *) items;

@end

//Base class for different parsers.
@interface MARCParserOperation : NSOperation<CernMediaMarcParserDelegate>

- (id) initWithURLString : (NSString *) urlString resourceTypes : (NSArray *) resourceTypes;

@property (nonatomic, weak) id<MARCParserOperationDelegate> delegate;

@end

//Videos.
@interface VideoCollectionsParserOperation : MARCParserOperation

- (id) initWithURLString : (NSString *) urlString resourceTypes : (NSArray *) resourceTypes;

@end