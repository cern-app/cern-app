//
//  ImageStackCellView.m
//  CERN
//
//  Created by Timur Pocheptsov on 5/21/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

#import "ImageStackViewCell.h"

@implementation ImageStackViewCell

@synthesize imageView;

//________________________________________________________________________________________
- (id) initWithFrame : (CGRect) frame
{
   if (self = [super initWithFrame : frame]) {
      self.backgroundColor = [UIColor clearColor];

      for (NSInteger i = 2; i >= 0; --i) {
         CALayer * const layer = [CALayer layer];
         layer.frame = CGRectMake(4.f, 4.f, frame.size.width - 8.f, frame.size.height - 8.f);
         const CGFloat rotationAngle = 3.f * i * M_PI / 180.f;
         layer.transform = CATransform3DMakeRotation(rotationAngle, 0.f, 0.f, 1.f);
         layer.backgroundColor = [UIColor whiteColor].CGColor;
         [self.layer addSublayer : layer];
         layer.rasterizationScale = [UIScreen mainScreen].scale;
         layer.shouldRasterize = YES;
         layer.shadowColor = [UIColor blackColor].CGColor;
         layer.shadowOpacity = 0.5f;
         layer.shadowOffset = CGSizeMake(2.f, 2.f);
      }
      
      imageView = [[UIImageView alloc] initWithFrame : CGRectMake(8.f, 8.f, frame.size.width - 16.f, frame.size.height - 16.f)];
      imageView.contentMode = UIViewContentModeScaleAspectFill;
      imageView.clipsToBounds = YES;
      imageView.backgroundColor = [UIColor darkGrayColor];
      [self addSubview : imageView];
   }

   return self;
}


@end
