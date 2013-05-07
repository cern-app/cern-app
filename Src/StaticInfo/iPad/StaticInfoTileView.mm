//
//  StaticInfoTile.m
//  CERN
//
//  Created by Timur Pocheptsov on 5/7/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <cassert>

#import "StaticInfoTileView.h"

using namespace CernAPP;

//C++ constants have internal linkage.
const CGFloat tileMargin = 0.1f;//10%
const CGFloat titleHeight = 0.15f;
const CGFloat hGap = 0.05f;//if tile's w > h, gap between image and text.

@implementation StaticInfoTileView {
   UIImageView *imageView;
   UILabel *titleLabel;
   UILabel *textLabel;
}

@synthesize layoutHint;

//________________________________________________________________________________________
- (id) initWithFrame : (CGRect) frame
{
   if (self = [super initWithFrame : frame]) {
      imageView = [[UIImageView alloc] initWithFrame : CGRect()];
      imageView.clipsToBounds = YES;
      imageView.contentMode = UIViewContentModeScaleAspectFill;;
      [self addSubview : imageView];
      
      //Title.
      titleLabel = [[UILabel alloc] initWithFrame:CGRect()];
      UIFont * const titleFont = [UIFont fontWithName : @"PTSans-Bold" size : 24.f];
      assert(titleFont != nil && "initWithFrame:, custom font is nil");
      titleLabel.font = titleFont;
      titleLabel.numberOfLines = 1;
      [self addSubview : titleLabel];

      //Text.
      textLabel = [[UILabel alloc] initWithFrame : CGRect()];
      UIFont * const textFont = [UIFont fontWithName : @"PTSans-Caption" size : 16.f];
      assert(textFont != nil && "initWithFrame:, custom font is nil");
      textLabel.font = textFont;
      textLabel.numberOfLines = 0;
      [self addSubview : textLabel];

      layoutHint = StaticInfoTileHint::none;
      
      self.backgroundColor = [UIColor lightGrayColor];
   }

   return self;
}

//________________________________________________________________________________________
- (void) setImage : (UIImage *) image
{
   assert(image != nil && "setImage:, parameter 'image' is nil");

   imageView.image = image;
}

//________________________________________________________________________________________
- (void) setTitle : (NSString *) title
{
   assert(title && "setTitle:, parameter 'title' is nil");
   
   titleLabel.text = title;
}

//________________________________________________________________________________________
- (void) setText : (NSString *) text
{
   assert(text != nil && "setText:, parameter 'text' is nil");
   
   textLabel.text = text;
}

//________________________________________________________________________________________
- (void) layoutTile
{
   assert(layoutHint != StaticInfoTileHint::none &&
          "layoutContents, layoutHint is invalid");

   const CGFloat w = self.frame.size.width;
   const CGFloat h = self.frame.size.height;
   if (w > h) {
      if (layoutHint == StaticInfoTileHint::scheme1) {//Image is on the left.
         //Image.
         const CGRect imageFrame = CGRectMake(w * tileMargin, h * tileMargin, w - 2 * w * tileMargin, h - 2 * h * tileMargin);
         imageView.frame = imageFrame;
         //Title.
         const CGRect titleFrame = CGRectMake(imageFrame.origin.x + imageFrame.size.width + w * hGap, h * tileMargin,
                                              w / 2 - hGap * w - w * tileMargin, h * titleHeight);
         titleLabel.frame = titleFrame;
         //Text.
         const CGRect textFrame = CGRectMake(titleFrame.origin.x, titleFrame.origin.y + titleFrame.size.height, titleFrame.size.width,
                                             imageFrame.size.height - titleFrame.size.height);
         textLabel.frame = textFrame;
      } else {//Image is on the right.
         //Title.
         const CGRect titleFrame = CGRectMake(w * tileMargin, h * tileMargin, (w - 2 * tileMargin * w) / 2, h * titleHeight);
         titleLabel.frame = titleFrame;
         //Text.
         const CGRect textFrame = CGRectMake(titleFrame.origin.x, titleFrame.origin.y + titleFrame.size.height, titleFrame.size.width, h - 2 * h * tileMargin - h * titleHeight);
         textLabel.frame = textFrame;
         //Image.
         const CGRect imageFrame = CGRectMake(w / 2 + hGap * w, h * tileMargin, w / 2 - tileMargin * w - hGap * w, textFrame.size.height + h * titleHeight);
         imageView.frame = imageFrame;
      }
   } else {
      if (layoutHint == StaticInfoTileHint::scheme1) {//Image is on the top.
         //Image.
         const CGRect imageFrame = CGRectMake(tileMargin * w, tileMargin * h, w - 2 * tileMargin * w, (h - 2 * tileMargin * h - titleHeight * h) / 2);
         imageView.frame = imageFrame;
         //Title.
         const CGRect titleFrame = CGRectMake(imageFrame.origin.x, imageFrame.origin.y + imageFrame.size.height, imageFrame.size.width, h * titleHeight);
         titleLabel.frame = titleFrame;
         //Text.
         const CGRect textFrame = CGRectMake(imageFrame.origin.x, titleFrame.origin.y + titleFrame.size.height,
                                             imageFrame.size.width, imageFrame.size.height);
         textLabel.frame = textFrame;
      } else {//Image is at the bottom.
         //
         //Title.
         const CGRect titleFrame = CGRectMake(tileMargin * w, tileMargin * h, w - 2 * w * tileMargin, h * titleHeight);
         titleLabel.frame = titleFrame;
         //Text.
         const CGRect textFrame = CGRectMake(titleFrame.origin.x, titleFrame.origin.y + titleFrame.size.height, titleFrame.size.width,
                                             (h - (titleFrame.origin.y + titleFrame.size.height) - tileMargin * h) / 2);
         textLabel.frame = textFrame;
         //Image.
         const CGRect imageFrame = CGRectMake(titleFrame.origin.x, textFrame.origin.y + textFrame.size.height,
                                              titleFrame.size.width, textFrame.size.height);
         imageView.frame = imageFrame;
      }
   }
}

@end
