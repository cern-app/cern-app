//
//  TiledPageProtocol.h
//  CERN
//
//  Created by Timur Pocheptsov on 4/8/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol TiledPage <NSObject>

@required

@property (nonatomic) NSUInteger pageNumber;

//The next two methods are imposed by "infinite scroll view" with tiled pages :(
+ (NSRange) suggestRangeForward : (NSArray *) items startingFrom : (NSUInteger) index;
+ (NSRange) suggestRangeBackward : (NSArray *) items endingWith : (NSUInteger) index;

- (NSUInteger) setPageItems : (NSArray *) feedItems startingFrom : (NSUInteger) index;
- (void) clearPage;

@required
@property (nonatomic, readonly) NSRange pageRange;

- (void) setThumbnail : (UIImage *) thumbnailImage forTile : (NSUInteger) tileIndex doLayout : (BOOL) layout;
- (BOOL) tileHasThumbnail : (NSUInteger) tileIndex;

- (void) layoutTiles;

//Animations:
- (void) explodeTiles : (UIInterfaceOrientation) orientation;
//Actually, both CFTimeInterval and NSTimeInterval are typedefs for double.
- (void) collectTilesAnimatedForOrientation : (UIInterfaceOrientation) orientation from : (CFTimeInterval) start withDuration : (CFTimeInterval) duration;

@end
