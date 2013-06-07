//
//  PhotoAlbumFooterView.m
//  CERN
//
//  Created by Timur Pocheptsov on 5/23/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <cassert>

#import "PhotoAlbumFooterView.h"

@implementation PhotoAlbumFooterView

@synthesize albumDescription;

//________________________________________________________________________________________
+ (NSString *) cellReuseIdentifier
{
   return @"PhotoAlbumFooterView";
}

//________________________________________________________________________________________
- (id) initWithFrame : (CGRect) frame
{
   if (self = [super initWithFrame : frame]) {
      // Initialization code
      self.backgroundColor = [UIColor clearColor];

      albumDescription = [[UILabel alloc] initWithFrame : CGRect()];
      albumDescription.textColor = [UIColor whiteColor];
      frame.origin = CGPoint();
      albumDescription.frame = frame;
      albumDescription.numberOfLines = 0;
      albumDescription.backgroundColor = [UIColor clearColor];
      albumDescription.clipsToBounds = YES;
      
      albumDescription.textAlignment = NSTextAlignmentCenter;
      
      self.autoresizesSubviews = YES;
      albumDescription.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
                                          UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
                                          UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
      [self addSubview : albumDescription];
   }

   return self;
}

//________________________________________________________________________________________
- (NSString *) reuseIdentifier
{
   return [PhotoAlbumFooterView cellReuseIdentifier];
}

@end
