//
//  CAPPPageControl.mm
//  Infinite page control for CERN.app
//
//  Created by Timur Pocheptsov on 16/12/13.
//

#import <algorithm>
#import <cassert>

#import "CAPPPageControl.h"
#import "CAPPPageView.h"

namespace {

const CGSize defaultSize = CGSizeMake(400.f, 50.f);
const CGFloat defaultLabelFontSize = 14.f;
const NSUInteger fastNavigatePages = 5;

}

@implementation CAPPPageControl {
   UILabel *leftLabel;
   UILabel *rightLabel;
   
   CAPPPageView *pageView;
   BOOL hasRecognizers;
}

@synthesize delegate;

//________________________________________________________________________________
- (instancetype) initWithFrame : (CGRect) frame
{
   if (self = [super initWithFrame : frame]) {
      [self createSubviews];
      hasRecognizers = NO;
      [self layoutSubviews : frame];
   }

   return self;
}

//________________________________________________________________________________
- (instancetype) initWithCoder : (NSCoder *) aDecoder
{
   if (self = [super initWithCoder : aDecoder]) {
      [self createSubviews];
      hasRecognizers = NO;
   }
   
   return self;
}

//________________________________________________________________________________
- (void) createSubviews
{
   assert(pageView == nil && "createChildView, page view is nil");
   
   //
   pageView = [[CAPPPageView alloc] initWithFrame : CGRect()];
   [self addSubview : pageView];
   //
   UIFontDescriptor * const labelFD = [UIFontDescriptor preferredFontDescriptorWithTextStyle : UIFontTextStyleCaption2];
   assert(labelFD != nil && "createChildViews, failed to create a font descriptor");
   UIFont * const labelFont = [UIFont fontWithDescriptor : labelFD size : defaultLabelFontSize];
   
   leftLabel = [[UILabel alloc] initWithFrame : CGRect()];
   leftLabel.backgroundColor = [UIColor clearColor];
   leftLabel.font = labelFont;
   leftLabel.text = @"Page 1";
   leftLabel.textColor = [UIColor darkGrayColor];
   [self addSubview : leftLabel];
   leftLabel.hidden = YES;
   leftLabel.userInteractionEnabled = YES;
   
   rightLabel = [[UILabel alloc] initWithFrame : CGRect()];
   rightLabel.backgroundColor = [UIColor clearColor];
   rightLabel.font = labelFont;
   rightLabel.text = @"Last page";
   rightLabel.textColor = [UIColor darkGrayColor];
   [self addSubview : rightLabel];
   rightLabel.hidden = YES;
   rightLabel.userInteractionEnabled = YES;
}

#pragma mark - Geometry and layout.

//________________________________________________________________________________
- (void) layoutSubviews : (CGRect) frame
{
   //I do not check that frame is wide enough and high to place all the staff. It should be forced externally.
   const CGSize leftLabelSize = [leftLabel.text sizeWithAttributes : @{NSFontAttributeName : leftLabel.font}];
   const CGSize rightLabelSize = [rightLabel.text sizeWithAttributes : @{NSFontAttributeName : rightLabel.font}];
   const CGSize labelSize = CGSizeMake(std::max(leftLabelSize.width, rightLabelSize.width), std::max(leftLabelSize.height, rightLabelSize.height));
   
   //Left label.
   leftLabel.frame = CGRectMake(labelSize.width / 2 - leftLabelSize.width / 2,
                                frame.size.height / 2. - leftLabelSize.height / 2,
                                leftLabelSize.width, leftLabelSize.height);
   
   //"Hint" for a pageView's frame.
   const CGRect hintFrame = CGRectMake(labelSize.width, 0.f, frame.size.width - labelSize.width * 2, frame.size.height);
   //Right label with such a hint.
   rightLabel.frame = CGRectMake(hintFrame.origin.x + hintFrame.size.width + labelSize.width / 2 - rightLabelSize.width / 2,
                                 frame.size.height / 2 - rightLabelSize.height / 2, rightLabelSize.width, rightLabelSize.height);
   [pageView layoutInRect : hintFrame];
   [pageView setNeedsDisplay];
}

//________________________________________________________________________________
- (void) layoutSubviews
{
   if (!pageView)
      [self createSubviews];

   [self layoutSubviews : self.frame];
   
   if (!hasRecognizers) {
      UITapGestureRecognizer * const tap1 = [[UITapGestureRecognizer alloc] initWithTarget : self action : @selector(jumpToFirstPage:)];
      [leftLabel addGestureRecognizer : tap1];

      UITapGestureRecognizer * const tap2 = [[UITapGestureRecognizer alloc] initWithTarget : self action : @selector(jumpToLastPage:)];
      [rightLabel addGestureRecognizer : tap2];
      
      UITapGestureRecognizer * const tap3 = [[UITapGestureRecognizer alloc] initWithTarget : self action : @selector(jumpToPage:)];
      [pageView addGestureRecognizer : tap3];
      
      hasRecognizers = YES;
   }
}

#pragma mark - page control interface.

//________________________________________________________________________________
- (void) setNumberOfPages : (NSUInteger) nPages
{
   if (!pageView)
      [self createSubviews];
   
   if (nPages != pageView.numberOfPages) {
      pageView.numberOfPages = nPages;//This also resets active page to 0.
      
      if (nPages < fastNavigatePages) {
         leftLabel.hidden = YES;
         rightLabel.hidden = YES;
      } else {
         leftLabel.hidden = NO;
         rightLabel.hidden = NO;
      }
      
      pageView.hidden = nPages == 1;
      
      [self setNeedsLayout];
   }
}

//________________________________________________________________________________
- (NSUInteger) numberOfPages
{
   return pageView.numberOfPages;//0 if pageView is nil, still ok.
}

//________________________________________________________________________________
- (void) setActivePage : (NSUInteger) activePage
{
   assert(pageView != nil && "setActivePage:, page view is nil");
   
   assert(activePage < pageView.numberOfPages && "setActivePageNumber:, parameter 'activePage' is out of bounds");

   pageView.activePage = activePage;
}

//________________________________________________________________________________
- (NSUInteger) activePage
{
   return pageView.activePage;//0 if pageView is nil, still ok.
}

#pragma mark - user interaction.

//________________________________________________________________________________
- (BOOL) interestedInTouch : (UITouch *) touch
{
   assert(touch != nil && "interestedInTouch:, parameter 'touch' is nil");
   return touch.view == self || touch.view == leftLabel || touch.view == rightLabel || touch.view == pageView;
}

//________________________________________________________________________________
- (void) jumpToFirstPage : (UITapGestureRecognizer *) tap
{
#pragma unused(tap)

   if (pageView.numberOfPages) {
      pageView.activePage = 0;
      if (delegate && [delegate respondsToSelector : @selector(pageControl:selectedPage:)])
         [delegate pageControl : self selectedPage : 0];
   }
}

//________________________________________________________________________________
- (void) jumpToLastPage : (UITapGestureRecognizer *) tap
{
#pragma unused(tap)

   if (const NSUInteger nPages = pageView.numberOfPages) {
      pageView.activePage = nPages - 1;
      if (delegate && [delegate respondsToSelector : @selector(pageControl:selectedPage:)])
         [delegate pageControl : self selectedPage : nPages - 1];
   }
}

//________________________________________________________________________________
- (void) jumpToPage : (UITapGestureRecognizer *) tap
{
   assert(tap != nil && "jumpToPage:, parameter 'tap' is nil");

   if ([pageView selectPageAtPoint : [tap locationInView : pageView]]) {
      if (delegate && [delegate respondsToSelector : @selector(pageControl:selectedPage:)])
         [delegate pageControl : self selectedPage : pageView.activePage];
   }
}

@end
