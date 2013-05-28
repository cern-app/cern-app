//
//  WebcastViewCell.h
//  CERN
//
//  Created by Timur Pocheptsov on 5/27/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import "PhotoAlbumCoverView.h"

@class MWFeedItem;

@interface VideoThumbnailCell : PhotoAlbumCoverView

- (void) setCellData : (MWFeedItem *) itemData;

@end
