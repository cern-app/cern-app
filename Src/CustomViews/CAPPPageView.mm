//
//  CAPPPageView.m
//  infinite_page_control
//
//  Created by Timur Pocheptsov on 16/12/13.
//  Copyright (c) 2013 Timur Pocheptsov. All rights reserved.
//

#import <algorithm>

#import "CAPPPageView.h"

const CGFloat circleRadius = 3.f;
const CGFloat pegRadius = 7.f;
const CGFloat dotRadius = 5.f;
const CGFloat fontSize = 7.f;

@implementation CAPPPageView {
   NSUInteger numberOfPages;
   NSUInteger activePage;
   
   UIFont *textFont;
   CGFloat textHeight;
}

//________________________________________________________________________________
+ (CGFloat) defaultCellWidth
{
   return 60.f;
}

//________________________________________________________________________________
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
   }

   return self;
}

//________________________________________________________________________________
- (void) drawRect : (CGRect) rect
{
   UIColor * const strokeColor = [UIColor darkGrayColor];
   [strokeColor setStroke];

   const CGFloat defaultCellWidth = [CAPPPageView defaultCellWidth];
   CGFloat xCentre = defaultCellWidth / 2;
   const CGFloat yCentre = rect.size.height / 2;
   for (NSUInteger i = 0; i < numberOfPages; ++i, xCentre += defaultCellWidth) {
   
      if (i != activePage) {
         const CGRect r = CGRectMake(xCentre - circleRadius,//x
                                     yCentre - circleRadius,//y
                                     2 * circleRadius, 2 * circleRadius);//w, h
         UIBezierPath * const circle = [UIBezierPath bezierPathWithOvalInRect : r];
         [circle setLineWidth : 1.f];
         [circle stroke];
      } else {
         [self drawPegAtPoint : CGPointMake(xCentre, yCentre)];
         [strokeColor setStroke];//Text in a peg is blue.
      }
   }
}

#pragma mark - properties.

//________________________________________________________________________________
- (void) setNumberOfPages : (NSUInteger) aNumberOfPages
{
   numberOfPages = aNumberOfPages;
   activePage = 0;
   
   if (numberOfPages)
      [self setNeedsDisplay];
}

//________________________________________________________________________________
- (NSUInteger) numberOfPages
{
   return numberOfPages;
}

//________________________________________________________________________________
- (void) setActivePage : (NSUInteger) anActivePage
{
   assert(anActivePage < numberOfPages && "setActivePage:, parameter 'anActivePage' is out of bounds");

   if (activePage != anActivePage) {
      activePage = anActivePage;
      [self setNeedsDisplay];
   }
}

//________________________________________________________________________________
- (NSUInteger) activePage
{
   return activePage;
}

#pragma mark - Aux. methods.

//________________________________________________________________________________
- (void) drawPegAtPoint : (CGPoint) centre
{
   //Aux function to show the active page.
   const CGRect rect = CGRectMake(centre.x - pegRadius, centre.y - pegRadius, pegRadius * 2, pegRadius * 2);
   UIBezierPath * const circle = [UIBezierPath bezierPathWithOvalInRect : rect];
   [circle setLineWidth : 1.5f];
   [circle stroke];

   const CGRect fillRect = CGRectMake(centre.x - dotRadius,
                                      centre.y - dotRadius,
                                      dotRadius * 2, dotRadius * 2);
   
   UIBezierPath * const filledCircle = [UIBezierPath bezierPathWithOvalInRect : fillRect];
   [[UIColor orangeColor] set];
   [filledCircle fill];
         
   if (activePage + 1 < 100) {//2-digits, must fit.
      assert(textFont != nil && "drawPegAtPoint:, textFont is nil");
      
      NSMutableParagraphStyle * const paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
      paragraphStyle.alignment = NSTextAlignmentCenter;

      NSDictionary * const attributes = @{NSFontAttributeName : textFont,
                                          NSParagraphStyleAttributeName : paragraphStyle,
                                          NSForegroundColorAttributeName : [UIColor blueColor]};
      
      const CGRect textRect = CGRectMake(centre.x - fillRect.size.width / 2,//x
                                         centre.y - textHeight / 2,//y
                                         fillRect.size.width, textHeight);//w, h
      NSString * const text = [NSString stringWithFormat : @"%u", unsigned(activePage + 1)];
      [text drawInRect : textRect withAttributes : attributes];
   }
}

@end
