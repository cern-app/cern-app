//
//  PhotoAlbumCoverView.h
//  CERN
//
//  Created by Timur Pocheptsov on 5/21/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PhotoAlbumCoverView : UICollectionViewCell

@property (nonatomic, readonly) UIImageView *imageView;
@property (nonatomic) NSString *title;

@end
