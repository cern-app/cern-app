//
//  PhotoAlbumCoverView.h
//  CERN
//
//  Created by Timur Pocheptsov on 5/21/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PhotoAlbumCoverView : UICollectionViewCell

- (id) initWithFrame : (CGRect) frame;//Use ImageStackCellView to show a thumbnail.
- (id) initWithUIImageView : (CGRect) frame;//Use UIImageView to show a thumbnail.

@property (nonatomic, readonly) UIImageView *imageView;
@property (nonatomic) NSString *title;

@end
