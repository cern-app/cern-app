//
//  PhotoAlbumFooterView.h
//  CERN
//
//  Created by Timur Pocheptsov on 5/23/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PhotoAlbumFooterView : UICollectionReusableView

+ (NSString *) cellReuseIdentifier;

@property (nonatomic, readonly) UILabel *albumDescription;

@end
