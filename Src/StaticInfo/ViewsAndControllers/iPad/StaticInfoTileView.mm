//
//  StaticInfoTile.m
//  CERN
//
//  Created by Timur Pocheptsov on 5/7/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <algorithm>
#import <cassert>

#import "StaticInfoTileView.h"
#import "DeviceCheck.h"

namespace CernAPP {

NSString * const StaticInfoItemNotification = @"CERN_APP_StaticInfoItemNotification";

}

using namespace CernAPP;

//C++ constants have internal linkage.
const CGFloat tileMargin = 0.02f;
const CGFloat titleHeight = 0.15f;
const CGFloat hGap = 0.05f;//if tile's w > h, gap between image and text.

@implementation StaticInfoTileView {
   UIImageView *imageView;
   UILabel *titleLabel;
   UILabel *textLabel;
}

@synthesize layoutHint, itemIndex;

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
      UIFont * const titleFont = [UIFont fontWithName : @"PTSans-Bold" size : 26.f];
      assert(titleFont != nil && "initWithFrame:, custom font is nil");
      titleLabel.font = titleFont;
      titleLabel.numberOfLines = 0;
      titleLabel.backgroundColor = [UIColor clearColor];
      [self addSubview : titleLabel];

      //Text.
      textLabel = [[UILabel alloc] initWithFrame : CGRect()];
      UIFont * const textFont = [UIFont fontWithName : @"PTSans-Caption" size : 20.f];
      assert(textFont != nil && "initWithFrame:, custom font is nil");
      textLabel.font = textFont;
      textLabel.numberOfLines = 0;
      textLabel.backgroundColor = [UIColor clearColor];
      [self addSubview : textLabel];

      layoutHint = StaticInfoTileHint::none;
      
      if (CernAPP::SystemVersionGreaterThanOrEqualTo(@"7.0"))
         self.backgroundColor = [UIColor whiteColor];
      else
         self.backgroundColor = [UIColor colorWithRed : 0.85f green : 0.85f blue : 0.85f alpha : 1.f];
      
      UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget : self action : @selector(handleTap:)];
      [self addGestureRecognizer : tapRecognizer];
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
   //TODO: fix this nightmarish spaghetti nightmare.

   assert(layoutHint != StaticInfoTileHint::none &&
          "layoutContents, layoutHint is invalid");

   const CGFloat w = self.frame.size.width;
   const CGFloat h = self.frame.size.height;
   if (w > h) {
      if (layoutHint == StaticInfoTileHint::scheme1) {//Image is on the left.
         //Image.
         const CGRect imageFrame = CGRectMake(w * tileMargin, h * tileMargin, (w - 2 * w * tileMargin) / 2, h - 2 * h * tileMargin);
         imageView.frame = imageFrame;
         //Title.
         const CGRect titleFrame = CGRectMake(imageFrame.origin.x + imageFrame.size.width + w * hGap, h * tileMargin,
                                              w / 2 - hGap * w - w * tileMargin, h * titleHeight);
         titleLabel.frame = titleFrame;
         //Text.
         const CGSize descriptionSize = [textLabel.text sizeWithFont : textLabel.font constrainedToSize : CGSizeMake(titleFrame.size.width, CGFLOAT_MAX)];
         const CGRect textFrame = CGRectMake(titleFrame.origin.x, titleFrame.origin.y + titleFrame.size.height, titleFrame.size.width,
                                             std::min(imageFrame.size.height - titleFrame.size.height, descriptionSize.height));
         textLabel.frame = textFrame;
      } else {//Image is on the right.
         //Title.
         const CGRect titleFrame = CGRectMake(w * tileMargin, h * tileMargin, (w - 2 * tileMargin * w) / 2, h * titleHeight);
         titleLabel.frame = titleFrame;
         //Text.
         //Text.
         const CGSize descriptionSize = [textLabel.text sizeWithFont : textLabel.font constrainedToSize : CGSizeMake(titleFrame.size.width, CGFLOAT_MAX)];
         const CGRect textFrame = CGRectMake(titleFrame.origin.x, titleFrame.origin.y + titleFrame.size.height, titleFrame.size.width,
                                             std::min(h - 2 * h * tileMargin - h * titleHeight, descriptionSize.height));
         textLabel.frame = textFrame;
         //Image.
         const CGRect imageFrame = CGRectMake(w / 2 + hGap * w, h * tileMargin, w / 2 - tileMargin * w - hGap * w, h - 2 * h * tileMargin);
         imageView.frame = imageFrame;
      }
   } else {
      if (layoutHint == StaticInfoTileHint::scheme1) {//Image is on the top.
         //Image.
         const CGRect imageFrame = CGRectMake(tileMargin * w, tileMargin * h, w - 2 * tileMargin * w, (h - 2 * tileMargin * h) / 2);
         imageView.frame = imageFrame;
         //Title.
         const CGRect titleFrame = CGRectMake(imageFrame.origin.x, imageFrame.origin.y + imageFrame.size.height, imageFrame.size.width, h * titleHeight);
         titleLabel.frame = titleFrame;
         //Text.
         const CGSize descriptionSize = [textLabel.text sizeWithFont : textLabel.font constrainedToSize : CGSizeMake(titleFrame.size.width, CGFLOAT_MAX)];
         const CGRect textFrame = CGRectMake(imageFrame.origin.x, titleFrame.origin.y + titleFrame.size.height,
                                             imageFrame.size.width, std::min(imageFrame.size.height - titleFrame.size.height, descriptionSize.height));
         textLabel.frame = textFrame;
      } else {//Image is at the bottom.
         //
         //Title.
         const CGRect titleFrame = CGRectMake(tileMargin * w, tileMargin * h, w - 2 * w * tileMargin, h * titleHeight);
         titleLabel.frame = titleFrame;
         //Text.
         const CGSize descriptionSize = [textLabel.text sizeWithFont : textLabel.font constrainedToSize : CGSizeMake(titleFrame.size.width, CGFLOAT_MAX)];
         const CGRect textFrame = CGRectMake(titleFrame.origin.x, titleFrame.origin.y + titleFrame.size.height, titleFrame.size.width,
                                             std::min((h - 2 * tileMargin * h) / 2 - titleFrame.size.height, descriptionSize.height));
         textLabel.frame = textFrame;
         //Image.
         
         const CGRect imageFrame = CGRectMake(titleFrame.origin.x, h / 2,
                                              titleFrame.size.width, (h - 2 * tileMargin * h) / 2);
         imageView.frame = imageFrame;
      }
   }
}

//________________________________________________________________________________________
- (void) handleTap : (UITapGestureRecognizer *) tapRecognizer
{
   assert(tapRecognizer != nil && "handleTap:, parameter 'tapRecognizer' is nil");
   
   // If the photo was tapped, display it fullscreen
   if (CGRectContainsPoint(imageView.frame, [tapRecognizer locationInView : self])) {
      NSNumber * const value = [NSNumber numberWithUnsignedInteger : itemIndex];
      [[NSNotificationCenter defaultCenter] postNotificationName : StaticInfoItemNotification object : value];
   }
}

@end
