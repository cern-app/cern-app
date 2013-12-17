//
//  CAPPPageView.m
//  infinite_page_control
//
//  Created by Timur Pocheptsov on 16/12/13.
//  Copyright (c) 2013 Timur Pocheptsov. All rights reserved.
//

#import <algorithm>

#import "CAPPPageView.h"

const CGFloat circleRadius = 8.f;
const CGFloat dotRadius = 5.f;
const CGFloat fontSize = 6.f;

@implementation CAPPPageView {
   NSUInteger numberOfPages;
   NSUInteger activePage;
   
   UIFont *textFont;
   CGFloat textHeight;
}

//________________________________________________________________________________________
+ (CGFloat) defaultCellWidth
{
   return 60.f;
}

//________________________________________________________________________________________
- (instancetype) initWithFrame : (CGRect) frame
{
   if (self = [super initWithFrame : frame]) {
      numberOfPages = 0;
      activePage = 0;
      
      self.backgroundColor = [UIColor clearColor];
      self.opaque = NO;
      
      UIFontDescriptor * const textFD = [UIFontDescriptor preferredFontDescriptorWithTextStyle : UIFontTextStyleFootnote];
      textFont = [UIFont fontWithDescriptor:textFD size : fontSize];
      textHeight = [@"0123456789" sizeWithAttributes : @{NSFontAttributeName : textFont}].height;//:)
      
      self.layer.shadowColor = [UIColor darkGrayColor].CGColor;
      self.layer.shadowOffset = CGSizeMake(2.f, 2.f);
      self.layer.shadowOpacity = 0.5f;
   }

   return self;
}

//________________________________________________________________________________________
- (void) drawRect : (CGRect) rect
{
   UIColor * const strokeColor = [UIColor darkGrayColor];
   CGFloat nextX = 0.f;

   const CGFloat defaultCellWidth = [CAPPPageView defaultCellWidth];

   for (NSUInteger i = 0; i < numberOfPages; ++i, nextX += defaultCellWidth) {
      const CGRect dotRect = CGRectMake(nextX + defaultCellWidth / 2 - circleRadius,//x
                                        rect.size.height / 2 - circleRadius,//y
                                        2 * circleRadius, 2 * circleRadius);//w, h
      UIBezierPath * const circle = [UIBezierPath bezierPathWithOvalInRect : dotRect];
      [circle setLineWidth : 1.5f];
      [strokeColor setStroke];
      [circle stroke];

      if (i == activePage)
         [self drawPegInRect : dotRect];
   }
}

#pragma mark - properties.

//________________________________________________________________________________________
- (void) setNumberOfPages : (NSUInteger) aNumberOfPages
{
   numberOfPages = aNumberOfPages;
   activePage = 0;
   
   if (numberOfPages)
      [self setNeedsDisplay];
}

//________________________________________________________________________________________
- (NSUInteger) numberOfPages
{
   return numberOfPages;
}

//________________________________________________________________________________________
- (void) setActivePage : (NSUInteger) anActivePage
{
   assert(anActivePage < numberOfPages && "setActivePage:, parameter 'anActivePage' is out of bounds");

   if (activePage != anActivePage) {
      activePage = anActivePage;
      [self setNeedsDisplay];
   }
}

//________________________________________________________________________________________
- (NSUInteger) activePage
{
   return activePage;
}

#pragma mark - Aux. methods.

//________________________________________________________________________________________
- (void) drawPegInRect : (CGRect) circleRect
{
   //Aux function to show the active page.
   const CGRect fillRect = CGRectMake(circleRect.origin.x + circleRadius - dotRadius,
                                      circleRect.origin.y + circleRadius - dotRadius,
                                      dotRadius * 2, dotRadius * 2);
   
   UIBezierPath * const filledCircle = [UIBezierPath bezierPathWithOvalInRect : fillRect];
   [[UIColor orangeColor] set];
   [filledCircle fill];
         
   if (activePage + 1 < 100) {//2-digits, must fit.
      assert(textFont != nil && "drawPegInRect:, textFont is nil");
      
      NSMutableParagraphStyle * const paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
      paragraphStyle.alignment = NSTextAlignmentCenter;

      NSDictionary * const attributes = @{NSFontAttributeName : textFont,
                                          NSParagraphStyleAttributeName : paragraphStyle,
                                          NSForegroundColorAttributeName : [UIColor blueColor]};
      
      const CGRect textRect = CGRectMake(fillRect.origin.x,//x
                                         fillRect.origin.y + fillRect.size.height / 2 - textHeight / 2,//y
                                         fillRect.size.width, textHeight);//w, h
      NSString * const text = [NSString stringWithFormat : @"%u", unsigned(activePage + 1)];
      [text drawInRect : textRect withAttributes : attributes];
   }
}

@end
