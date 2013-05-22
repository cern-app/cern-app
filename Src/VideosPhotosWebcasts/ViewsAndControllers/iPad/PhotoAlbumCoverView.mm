//
//  PhotoAlbumCoverView.m
//  CERN
//
//  Created by Timur Pocheptsov on 5/21/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <cassert>

#import "PhotoAlbumCoverView.h"
#import "ImageStackCellView.h"

@implementation PhotoAlbumCoverView {
   ImageStackCellView *imageStackView;
   UILabel *titleLabel;
}

#pragma mark - Lifecycle.

//________________________________________________________________________________________
- (id) initWithFrame : (CGRect) frame
{
   if (self = [super initWithFrame : frame]) {
      CGRect stackFrame = {};
      stackFrame.size.width = frame.size.width * 0.7f;
      stackFrame.size.height = frame.size.height * 0.7f;
      
      stackFrame.origin.x = 0.15f * frame.size.width;
      stackFrame.origin.y = 0.15f * frame.size.height;
      
      imageStackView = [[ImageStackCellView alloc] initWithFrame : stackFrame];
      [self addSubview : imageStackView];
      
      CGRect titleFrame = {};
      titleFrame.size.width = frame.size.width * 0.9f;
      titleFrame.size.height = frame.size.height * 0.3f;
      
      titleFrame.origin.x = 0.05f * frame.size.width;
      titleFrame.origin.y = 0.85f * frame.size.height;
      
      titleLabel = [[UILabel alloc] initWithFrame : titleFrame];
      titleLabel.clipsToBounds = YES;
      titleLabel.backgroundColor = [UIColor clearColor];
      titleLabel.numberOfLines = 0;
      
      UIFont * const titleFont = [UIFont systemFontOfSize : 10.f];
      titleLabel.font = titleFont;
      titleLabel.textColor = [UIColor whiteColor];
      titleLabel.textAlignment = NSTextAlignmentCenter;
      [self addSubview : titleLabel];
   }

   return self;
}

#pragma mark - Setters/getters.

//________________________________________________________________________________________
- (UIImageView *) imageView
{
   assert(imageStackView != nil && "imageView, imageStackView is nil");
   assert(imageStackView.imageView != nil && "imageView, imageStackView.imageView is nil");

   return imageStackView.imageView;
}

//________________________________________________________________________________________
- (NSString *) title
{
   assert(titleLabel != nil && "title, titleLabel is nil");

   return titleLabel.text;
}

//________________________________________________________________________________________
- (void) setTitle : (NSString *) title
{
   assert(titleLabel != nil && "setTitle:, parameter 'title' is nil");
   
   titleLabel.text = title;
}

#pragma mark - Reuse cell.

//________________________________________________________________________________________
- (void) prepareForReuse
{
   imageStackView.imageView.image = nil;
   titleLabel.text = nil;
}

//________________________________________________________________________________________
- (NSString *) reuseIdentifier
{
   return @"PhotoAlbumCoverView";
}

@end
