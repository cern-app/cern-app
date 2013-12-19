//
//  CAPPPageControlPegView.m
//  CERN
//
//  Created by Timur Pocheptsov on 19/12/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import "CAPPPageControlPegView.h"

const CGFloat pegRadius = 7.f;
const CGFloat dotRadius = 5.f;
const CGFloat fontSize = 6.f;
const CGFloat fontSizeExtraSmall = 4.5f;

@implementation CAPPPageControlPegView {
   CGFloat textHeight;
   CGFloat textHeightExtraSmall;
   
   UIBezierPath *circle;
   UIBezierPath *filledCircle;
   
   NSDictionary *textAttributes;
   NSDictionary *extraSmallTextAttributes;
}

@synthesize activePage;

//________________________________________________________________________________________
+ (CGRect) pegFrame
{
   return CGRectMake(0.f, 0.f, pegRadius * 2, pegRadius * 2);
}

//________________________________________________________________________________________
- (instancetype) initWithFrame : (CGRect) frame
{
   if (self = [super initWithFrame : frame]) {
      self.backgroundColor = [UIColor clearColor];
      self.opaque = NO;

      //Font's and text attributes.
      UIFontDescriptor * const textFD = [UIFontDescriptor preferredFontDescriptorWithTextStyle : UIFontTextStyleFootnote];

      UIFont * const textFont = [UIFont fontWithDescriptor : textFD size : fontSize];
      assert(textFont != nil && "initWithFrame:, text font is nil");

      NSMutableParagraphStyle * const paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
      paragraphStyle.alignment = NSTextAlignmentCenter;
      
      textAttributes = @{NSFontAttributeName : textFont,
                         NSParagraphStyleAttributeName : paragraphStyle,
                         NSForegroundColorAttributeName : [UIColor blueColor]};
      textHeight = [@"0123456789" sizeWithAttributes : @{NSFontAttributeName : textFont}].height;//:)
      
      UIFont * const textFontExtraSmall = [UIFont fontWithDescriptor : textFD size : fontSizeExtraSmall];
      assert(textFontExtraSmall != nil && "initWithFrame:, textFontExtraSmall is nil");
      
      extraSmallTextAttributes = @{NSFontAttributeName : textFontExtraSmall,
                                   NSParagraphStyleAttributeName : paragraphStyle,
                                   NSForegroundColorAttributeName : [UIColor blueColor]};
      textHeightExtraSmall = [@"0123456789" sizeWithAttributes : @{NSFontAttributeName : textFontExtraSmall}].height;//:)

      //Bezier paths.
      circle = [UIBezierPath bezierPathWithOvalInRect : frame];
      [circle setLineWidth : 1.5f];

      const CGPoint centre = CGPointMake(frame.size.width / 2, frame.size.height / 2);
      const CGRect fillRect = CGRectMake(centre.x - dotRadius,
                                         centre.y - dotRadius,
                                         dotRadius * 2, dotRadius * 2);
      filledCircle = [UIBezierPath bezierPathWithOvalInRect : fillRect];
   }

   return self;
}

//________________________________________________________________________________________
- (void) drawRect : (CGRect) rect
{
   //Well, actually I can have a self.layer with all this circles and only draw a number, but ... ok for now.
   [circle setLineWidth : 1.5f];
   [circle stroke];
   
   [[UIColor orangeColor] set];
   [filledCircle fill];
   
   const CGPoint centre = CGPointMake(rect.size.width / 2, rect.size.height / 2);
   const CGRect fillRect = CGRectMake(centre.x - dotRadius,
                                      centre.y - dotRadius,
                                      dotRadius * 2, dotRadius * 2);

   const CGRect textRect = CGRectMake(centre.x - fillRect.size.width / 2,//x
                                      activePage + 1 < 100 ? centre.y - textHeight / 2 : centre.y - textHeightExtraSmall / 2,//y
                                      fillRect.size.width, activePage + 1 < 100 ? textHeight : textHeightExtraSmall);//w, h
   NSString * const text = [NSString stringWithFormat : @"%u", unsigned(activePage + 1)];
   [text drawInRect : textRect withAttributes : activePage + 1 < 100 ? textAttributes : extraSmallTextAttributes];
}


@end
