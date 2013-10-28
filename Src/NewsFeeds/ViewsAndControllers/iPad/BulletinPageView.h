//
//  BulletinPageView.h
//  CERN
//
//  Created by Timur Pocheptsov on 4/11/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "TiledPage.h"

@interface BulletinPageView : UIView<TiledPage>

@property (nonatomic) NSUInteger pageNumber;

//The next two methods are imposed by "infinite scroll view" with tiled pages :(
+ (NSRange) suggestRangeForward : (NSArray *) items startingFrom : (NSUInteger) index;
+ (NSRange) suggestRangeBackward : (NSArray *) items endingWith : (NSUInteger) index;

- (NSUInteger) setPageItems : (NSArray *) feedItems startingFrom : (NSUInteger) index;
- (void) clearPage;

@property (nonatomic, readonly) NSRange pageRange;

- (void) setThumbnail : (UIImage *) thumbnailImage forTile : (NSUInteger) tileIndex doLayout : (BOOL) layout;
- (BOOL) tileHasThumbnail : (NSUInteger) tileIndex;

- (void) layoutTiles;

//Animations:
- (void) explodeTiles : (UIInterfaceOrientation) orientation;
//Actually, both CFTimeInterval and NSTimeInterval are typedefs for double.
- (void) collectTilesAnimatedForOrientation : (UIInterfaceOrientation) orientation from : (CFTimeInterval) start withDuration : (CFTimeInterval) duration;

@end
