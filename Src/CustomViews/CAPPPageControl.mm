//
//  CAPPPageControl.mm
//  Infinite page control for CERN.app
//
//  Created by Timur Pocheptsov on 16/12/13.
//

#import <algorithm>
#import <cassert>
#import <cmath>

#import "CAPPPageControl.h"
#import "CAPPPageView.h"

namespace {

const CGSize defaultSize = CGSizeMake(400.f, 50.f);
const CGFloat defaultLabelFontSize = 14.f;
const NSUInteger fastNavigatePages = 5;

//________________________________________________________________________________
bool EqualOffsets(CGFloat x1, CGFloat x2)
{
   return std::abs(x1 - x2) < 0.1;
}

}

@implementation CAPPPageControl {
   UILabel *leftLabel;
   UILabel *rightLabel;
   
   UIScrollView *scroll;//pageView is placed in a scroll view.
   CAPPPageView *pageView;
   
   BOOL informDelegateAfterAnimation;
}

@synthesize delegate, animating;

//________________________________________________________________________________
- (instancetype) initWithFrame : (CGRect) frame
{
   if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad)
      @throw [NSException exceptionWithName : @"CAPPPageControl's exception" reason : @"Unsupported UI idiom" userInfo : nil];


   if (self = [super initWithFrame : frame]) {
      [self createSubviews];
      [self layoutSubviews : frame];
      animating = NO;
      informDelegateAfterAnimation = NO;
   }

   return self;
}

//________________________________________________________________________________
- (instancetype) initWithCoder : (NSCoder *) aDecoder
{
   if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad)
      @throw [NSException exceptionWithName : @"CAPPPageControl's exception" reason : @"Unsupported UI idiom" userInfo : nil];


   if (self = [super initWithCoder : aDecoder]) {
      [self createSubviews];
      animating = NO;
      informDelegateAfterAnimation = NO;
   }
   
   return self;
}

//________________________________________________________________________________
- (void) createSubviews
{
   assert(pageView == nil && "createChildView, page view is nil");

   //
   scroll = [[UIScrollView alloc] initWithFrame : CGRect()];
   scroll.userInteractionEnabled = NO;
   scroll.showsHorizontalScrollIndicator = NO;
   scroll.showsVerticalScrollIndicator = NO;
   scroll.clipsToBounds = YES;
   scroll.delegate = self;
   [self addSubview : scroll];
   //
   pageView = [[CAPPPageView alloc] initWithFrame : CGRect()];
   [scroll addSubview : pageView];
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
   
   UITapGestureRecognizer * const tap1 = [[UITapGestureRecognizer alloc] initWithTarget : self action : @selector(jumpToFirstPage:)];
   [leftLabel addGestureRecognizer : tap1];

   UITapGestureRecognizer * const tap2 = [[UITapGestureRecognizer alloc] initWithTarget : self action : @selector(jumpToLastPage:)];
   [rightLabel addGestureRecognizer : tap2];

   UITapGestureRecognizer * const tap3 = [[UITapGestureRecognizer alloc] initWithTarget : self action : @selector(jumpToPage:)];
   [self addGestureRecognizer : tap3];
}

#pragma mark - Geometry and layout.

//________________________________________________________________________________
- (void) layoutSubviews : (CGRect) frame
{
   //What about the animation???
   assert(animating == NO && "layoutSubviews:, called while an animation is active");

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

   if (pageView.numberOfPages) {
      const CGFloat visibleW = NSUInteger(hintFrame.size.width / [CAPPPageView defaultCellWidth]) * [CAPPPageView defaultCellWidth];
      pageView.frame = CGRectMake(0.f, 0.f, [CAPPPageView defaultCellWidth] * pageView.numberOfPages, hintFrame.size.height);
      if (pageView.frame.size.width < visibleW)
         scroll.frame = CGRectMake(hintFrame.origin.x + hintFrame.size.width / 2 - pageView.frame.size.width / 2, hintFrame.origin.y, pageView.frame.size.width, hintFrame.size.height);
      else
         scroll.frame = CGRectMake(hintFrame.origin.x + hintFrame.size.width / 2 - visibleW / 2, hintFrame.origin.y, visibleW, hintFrame.size.height);
      scroll.contentSize = pageView.frame.size;
   } else {
      pageView.frame = hintFrame;
      scroll.frame = hintFrame;
      scroll.contentSize = hintFrame.size;
   }
}

//________________________________________________________________________________
- (void) layoutSubviews
{
   assert(animating == NO && "layoutSubviews, called while animating");

   if (!pageView)
      [self createSubviews];

   [self layoutSubviews : self.frame];
}

#pragma mark - page control interface.

//________________________________________________________________________________
- (void) setNumberOfPages : (NSUInteger) nPages
{
   if (animating)
      return;

   if (!pageView)
      [self createSubviews];
   
   if (nPages != pageView.numberOfPages) {
      pageView.numberOfPages = nPages;//This also resets active page to 0.
      
      leftLabel.hidden = nPages < fastNavigatePages;
      rightLabel.hidden = leftLabel.hidden;
      
      scroll.hidden = nPages == 1;

      informDelegateAfterAnimation = NO;
      rightLabel.text = [NSString stringWithFormat : @"Page %u", unsigned(nPages)];
      [self setNeedsLayout];
   }
}

//________________________________________________________________________________
- (NSUInteger) numberOfPages
{
   return pageView.numberOfPages;//0 if pageView is nil, still ok.
}

//________________________________________________________________________________
- (void) setActivePage : (NSUInteger) activePage informDelegate : (BOOL) inform
{
   if (animating)
      return;

   assert(pageView != nil && "setActivePage:, page view is nil");
   assert(activePage < pageView.numberOfPages && "setActivePageNumber:, parameter 'activePage' is out of bounds");

   pageView.activePage = activePage;
   informDelegateAfterAnimation = inform;
   [self adjustOffsetAnimated];
}

//________________________________________________________________________________
- (void) setActivePage : (NSUInteger) activePage
{
   [self setActivePage : activePage informDelegate : NO];
}

//________________________________________________________________________________
- (NSUInteger) activePage
{
   return pageView.activePage;//0 if pageView is nil, still ok.
}

#pragma mark - UIScrollViewDelegate and related methods.

//________________________________________________________________________________
- (void) adjustOffsetAnimated
{
   assert(animating == NO && "adjustOffsetAnimated, called while animating");
   
   const CGFloat cellW = [CAPPPageView defaultCellWidth];
   const CGFloat activePageX = pageView.activePage * cellW;
   if (EqualOffsets(activePageX, scroll.contentOffset.x)) {
      if (activePageX) {
         animating = YES;
         const CGFloat shift = std::min(scroll.contentOffset.x, 3 * cellW);
         [scroll setContentOffset : CGPointMake(activePageX - shift, 0.f) animated : YES];
      }
   } else if (EqualOffsets(activePageX - scroll.contentOffset.x, scroll.frame.size.width - cellW)) {
      if (pageView.activePage + 1 < pageView.numberOfPages) {
         animating = YES;
         const CGFloat shift = std::min(3 * cellW, scroll.contentSize.width - activePageX - cellW);
         [scroll setContentOffset : CGPointMake(scroll.contentOffset.x + shift, 0.f) animated : YES];
      }
   } else if (informDelegateAfterAnimation) {
      informDelegateAfterAnimation = NO;
      if (delegate && [delegate respondsToSelector : @selector(pageControl:selectedPage:)])
         [delegate pageControl : self selectedPage : pageView.activePage];
   }
}

//________________________________________________________________________________
- (void) scrollViewDidEndScrollingAnimation : (UIScrollView *) scrollView
{
   assert(animating == YES && "scrollViewDidEndDecelerating:, called while not animating");
   animating = NO;
   
   if (informDelegateAfterAnimation) {
      informDelegateAfterAnimation = NO;
      if (delegate && [delegate respondsToSelector : @selector(pageControl:selectedPage:)])
         [delegate pageControl : self selectedPage : pageView.activePage];
   }
}

#pragma mark - user interaction.

//________________________________________________________________________________
- (BOOL) interestedInTouch : (UITouch *) touch
{
   assert(touch != nil && "interestedInTouch:, parameter 'touch' is nil");
   return touch.view == self || touch.view == leftLabel || touch.view == rightLabel;
}

//________________________________________________________________________________
- (void) jumpToFirstPage : (UITapGestureRecognizer *) tap
{
#pragma unused(tap)

   if (animating)
      return;

   if (pageView.numberOfPages && pageView.activePage) {
      pageView.activePage = 0;
      [scroll setContentOffset : CGPoint() animated : NO];
      
      if (delegate && [delegate respondsToSelector : @selector(pageControl:selectedPage:)])
         [delegate pageControl : self selectedPage : 0];
   }
}

//________________________________________________________________________________
- (void) jumpToLastPage : (UITapGestureRecognizer *) tap
{
#pragma unused(tap)

   if (animating)
      return;

   if (const NSUInteger nPages = pageView.numberOfPages) {
      if (pageView.activePage != nPages - 1) {
         pageView.activePage = nPages - 1;
         if (scroll.contentSize.width > scroll.frame.size.width) {
            [scroll setContentOffset : CGPointMake(scroll.contentSize.width - scroll.frame.size.width, 0.f) animated : NO];
         }
         if (delegate && [delegate respondsToSelector : @selector(pageControl:selectedPage:)])
            [delegate pageControl : self selectedPage : nPages - 1];
      }
   }
}

//________________________________________________________________________________
- (void) jumpToPage : (UITapGestureRecognizer *) tap
{
   assert(tap != nil && "jumpToPage:, parameter 'tap' is nil");

   if (animating)
      return;

   CGPoint tapPoint = [tap locationInView : scroll];
   tapPoint.x -= scroll.contentOffset.x;
   CGRect scrollFrame = scroll.frame;
   scrollFrame.origin = CGPoint();

   if (CGRectContainsPoint(scrollFrame, tapPoint)) {
      tapPoint.x += scroll.contentOffset.x;
      tapPoint = [tap locationInView : pageView];
      const NSUInteger newPage = NSUInteger(tapPoint.x / [CAPPPageView defaultCellWidth]);

      if (newPage != pageView.activePage)
         [self setActivePage : newPage informDelegate : YES];
   }
}

@end
