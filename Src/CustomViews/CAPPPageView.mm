//
//  CAPPPageView.m
//  infinite_page_control
//
//  Created by Timur Pocheptsov on 16/12/13.
//  Copyright (c) 2013 Timur Pocheptsov. All rights reserved.
//

#import "CAPPPageView.h"

const CGFloat defaultCellWidth = 60.f;
const CGFloat circleRadius = 8.f;
const CGFloat dotRadius = 5.f;
const CGFloat fontSize = 6.f;

@implementation CAPPPageView {
   NSUInteger numberOfPages;
   NSUInteger hiddenPages;//"How many dots are on the left"
   NSUInteger activePage;
   
   UIFont *textFont;
   CGFloat textHeight;
   
}

//________________________________________________________________________________
- (instancetype) initWithFrame : (CGRect) frame
{
   if (self = [super initWithFrame : frame]) {
      numberOfPages = 0;
      hiddenPages = 0;
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
   CGFloat nextX = 0.f;
   
   const NSUInteger visible = rect.size.width / defaultCellWidth;
   for (NSUInteger i = hiddenPages, e = hiddenPages + visible; i < e; ++i, nextX += defaultCellWidth) {
      const CGRect dotRect = CGRectMake(nextX + defaultCellWidth / 2 - circleRadius,//x
                                        rect.size.height / 2 - circleRadius,//y
                                        2 * circleRadius, 2 * circleRadius);//w, h
      UIBezierPath * const circle = [UIBezierPath bezierPathWithOvalInRect : dotRect];
      [circle setLineWidth : 3.f];
      [strokeColor setStroke];
      [circle stroke];

      if (i == activePage)
         [self drawPegInRect : dotRect];
   }
}

//________________________________________________________________________________
- (void) layoutInRect : (CGRect) frameHint
{
   const CGFloat oldW = frameHint.size.width;//Before modification.
   const CGFloat requiredW = [self requiredWidth];

   if (requiredW <= oldW) {
      frameHint.origin.x = frameHint.origin.x + frameHint.size.width / 2 - requiredW / 2;
      frameHint.size.width = requiredW;
      self.frame = frameHint;
   } else {
      const CGFloat newW = NSUInteger(oldW / defaultCellWidth) * defaultCellWidth;
      frameHint.origin.x = frameHint.origin.x + frameHint.size.width / 2 - newW / 2;
      frameHint.size.width = newW;
      self.frame = frameHint;
   }
   
   [self adjustPageOffset];
}



//________________________________________________________________________________
- (CGFloat) requiredWidth
{
   return numberOfPages * defaultCellWidth;
}

#pragma mark - properties.

//________________________________________________________________________________
- (void) setNumberOfPages : (NSUInteger) aNumberOfPages
{
   numberOfPages = aNumberOfPages;
   hiddenPages = 0;
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
      [self adjustPageOffset];
      [self setNeedsDisplay];
   }
}

//________________________________________________________________________________
- (NSUInteger) activePage
{
   return activePage;
}

//________________________________________________________________________________
- (BOOL) selectPageAtPoint : (CGPoint) point
{
   CGRect frame = self.frame;
   frame.origin = CGPoint();
   
   if (CGRectContainsPoint(frame, point)) {
      const NSUInteger selected = NSUInteger(point.x / defaultCellWidth);
      //that's quite a stupid check though.
      assert(selected + hiddenPages < numberOfPages && "selectPage:atPoint, page out of range");
      //
      if (selected + hiddenPages != activePage) {
         self.activePage = hiddenPages + selected;
         return YES;
      }
   }
   
   return NO;
}

#pragma mark - Aux. methods.

//________________________________________________________________________________
- (void) adjustPageOffset
{
   const CGFloat w = self.frame.size.width;
   
   if (!w)
      return;
   
   const NSUInteger visible = NSUInteger(w / defaultCellWidth);//how many 'pages' can fit in our range.
   
   if (activePage < visible) {
      hiddenPages = 0;
   } else {
      const NSUInteger canBeHidden = (activePage / visible) * visible;
      if (numberOfPages - canBeHidden >= visible)
         hiddenPages = canBeHidden;
      else
         hiddenPages = numberOfPages - visible;
   }
   
   
}

//________________________________________________________________________________
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
