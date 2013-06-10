//
//  FeedParserOperation.h
//  CERN
//
//  Created by Timur Pocheptsov on 6/4/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MWFeedParser.h"

@protocol FeedParserOperationDelegate <NSObject>
@required
- (void) parserDidFailWithError : (NSError *) error;
- (void) parserDidFinishWithInfo : (MWFeedInfo *) info items : (NSArray *) items;

@end


@interface FeedParserOperation : NSOperation<MWFeedParserDelegate>

- (id) initWithFeedURLString : (NSString *) urlString;

@property (nonatomic, weak) NSObject<FeedParserOperationDelegate> *delegate;

@end
