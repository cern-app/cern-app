//
//  TileView.h
//  CERN
//
//  Created by Timur Pocheptsov on 3/18/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "MWFeedItem.h"

@interface FeedItemTileView : UIView

- (void) setTileData : (MWFeedItem *) feedItem;

- (void) setTileThumbnail : (UIImage *) image doLayout : (BOOL) layout;
- (BOOL) hasThumbnail;
- (void) layoutTile;

@end

namespace CernAPP {

extern NSString * const feedItemSelectionNotification;

}
