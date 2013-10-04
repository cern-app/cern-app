//
//  CDSVideosParser.h
//  CERN
//
//  Created by Timur Pocheptsov on 10/4/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import "CDSParser.h"

namespace CernAPP {

extern NSString * const CDSvideoURL;
extern NSString * const CDSvideoThubmnailURL;

}

@interface CDSVideosParserOperation : CDSParserOperation

- (id) initWithURLString : (NSString *) urlString datafieldTags : (NSSet *) tags
       subfieldCodes : (NSSet *) codes;

@end
