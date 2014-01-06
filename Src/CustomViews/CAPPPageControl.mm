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
const CGFloat buttonLabelMargin = 20.f;
const NSUInteger fastNavigatePages = 5;

//________________________________________________________________________________
bool EqualOffsets(CGFloat x1, CGFloat x2)
{
   return std::abs(x1 - x2) < 0.1;
}

}

@implementation CAPPPageControl {
   UIScrollView *scroll;//pageView is placed in a scroll view.
   CAPPPageView *pageView;
   
   UIButton *firstPage;
   UIButton *lastPage;
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
   }
   
   return self;
}

//________________________________________________________________________________
- (void) dealloc
{
   [NSObject cancelPreviousPerformRequestsWithTarget : self];
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
   scroll.decelerationRate = UIScrollViewDecelerationRateFast;
   scroll.bounces = NO;
   [self addSubview : scroll];
   //
   pageView = [[CAPPPageView alloc] initWithFrame : CGRect()];
   [scroll addSubview : pageView];
   
   firstPage = [UIButton buttonWithType : UIButtonTypeSystem];
   [firstPage setTitle : @"Page 1" forState : UIControlStateNormal];
   [self addSubview : firstPage];
   firstPage.hidden = YES;
   //Because of the Control Center buttons at the bottom of the screen are not working properly.
   firstPage.showsTouchWhenHighlighted = YES;
   
   lastPage = [UIButton buttonWithType : UIButtonTypeSystem];
   [lastPage setTitle : @"Last page" forState : UIControlStateNormal];
   [self addSubview : lastPage];
   lastPage.hidden = YES;
   lastPage.showsTouchWhenHighlighted = YES;

   [firstPage addTarget : self action : @selector(jumpToFirstPage) forControlEvents : UIControlEventTouchUpInside];
   [lastPage addTarget : self action : @selector(jumpToLastPage) forControlEvents : UIControlEventTouchUpInside];

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
   CGSize leftLabelSize = [firstPage.titleLabel.text sizeWithAttributes : @{NSFontAttributeName : firstPage.titleLabel.font}];
   leftLabelSize.width += buttonLabelMargin;
   
   CGSize rightLabelSize = [lastPage.titleLabel.text sizeWithAttributes : @{NSFontAttributeName : lastPage.titleLabel.font}];
   rightLabelSize.width += buttonLabelMargin;
   
   const CGSize labelSize = CGSizeMake(std::max(leftLabelSize.width, rightLabelSize.width), std::max(leftLabelSize.height, rightLabelSize.height));
   
   //"Page 1" button.
   firstPage.frame = CGRectMake(labelSize.width / 2 - leftLabelSize.width / 2,
                                frame.size.height / 2. - leftLabelSize.height / 2,
                                leftLabelSize.width, leftLabelSize.height);

   //"Hint" for a pageView's frame.
   const CGRect hintFrame = CGRectMake(labelSize.width, 0.f, frame.size.width - labelSize.width * 2, frame.size.height);
   //Right label with such a hint.
   
   //"Page N" button.
   lastPage.frame = CGRectMake(hintFrame.origin.x + hintFrame.size.width + labelSize.width / 2 - rightLabelSize.width / 2,
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
   
   pageView.numberOfPages = nPages;//This also resets active page to 0.
   
   firstPage.hidden = nPages < fastNavigatePages;
   lastPage.hidden = firstPage.hidden;
   
   scroll.hidden = nPages == 1;
   [lastPage setTitle : [NSString stringWithFormat : @"Page %u", unsigned(nPages)] forState : UIControlStateNormal];

   [self setNeedsLayout];
}

//________________________________________________________________________________
- (NSUInteger) numberOfPages
{
   return pageView.numberOfPages;//0 if pageView is nil, still ok.
}

//________________________________________________________________________________
- (void) setActivePage : (NSUInteger) activePage
{
   if (animating)
      return;

   assert(pageView != nil && "setActivePage:, page view is nil");
   assert(activePage < pageView.numberOfPages && "setActivePageNumber:, parameter 'activePage' is out of bounds");

   pageView.activePage = activePage;
   [self adjustOffsetAnimated];
}

//________________________________________________________________________________
- (NSUInteger) activePage
{
   return pageView.activePage;//0 if pageView is nil, still ok.
}

#pragma mark - UIScrollViewDelegate and related methods.

//________________________________________________________________________________
- (void) informDelegateAnimationDidEnd
{
   if (delegate && [delegate respondsToSelector : @selector(pageControlDidEndAnimating:)])
      [delegate pageControlDidEndAnimating : self];
}

//________________________________________________________________________________
- (void) adjustOffsetAnimated
{
   assert(animating == NO && "adjustOffsetAnimated, called while animating");
   
   const CGFloat cellW = [CAPPPageView defaultCellWidth];
   const CGFloat activePageX = pageView.activePage * cellW;
   if (EqualOffsets(activePageX, scroll.contentOffset.x)) {
      if (activePageX) {
         animating = YES;
         const CGFloat shift = std::min(scroll.contentOffset.x, 5 * cellW);
         [scroll setContentOffset : CGPointMake(activePageX - shift, 0.f) animated : YES];
      } else
         [self informDelegateAnimationDidEnd];
   } else if (EqualOffsets(activePageX - scroll.contentOffset.x, scroll.frame.size.width - cellW)) {
      if (pageView.activePage + 1 < pageView.numberOfPages) {
         animating = YES;
         const CGFloat shift = std::min(5 * cellW, scroll.contentSize.width - activePageX - cellW);
         [scroll setContentOffset : CGPointMake(scroll.contentOffset.x + shift, 0.f) animated : YES];
      } else
         [self informDelegateAnimationDidEnd];
   } else
      [self informDelegateAnimationDidEnd];
}

//________________________________________________________________________________
- (void) scrollViewDidEndScrollingAnimation : (UIScrollView *) scrollView
{
   assert(animating == YES && "scrollViewDidEndDecelerating:, called while not animating");
   animating = NO;
   
   [self informDelegateAnimationDidEnd];
}

#pragma mark - user interaction.

//________________________________________________________________________________
- (BOOL) interestedInTouch : (UITouch *) touch
{
   assert(touch != nil && "interestedInTouch:, parameter 'touch' is nil");
   return touch.view == self || touch.view == firstPage || touch.view == lastPage;
}

//________________________________________________________________________________
- (void) jumpToFirstPageAfterDelay
{
   if (pageView.numberOfPages && pageView.activePage) {
      pageView.activePage = 0;
      [scroll setContentOffset : CGPoint() animated : NO];
      [delegate pageControlSelectedPage : self];
   }
}

//________________________________________________________________________________
- (void) jumpToFirstPage
{
   if (animating)
      return;
   
   if (!delegate || ![delegate respondsToSelector : @selector(pageControlSelectedPage:)])
      return;

   if (pageView.numberOfPages && pageView.activePage) {
      [NSObject cancelPreviousPerformRequestsWithTarget : self];
      [self performSelector : @selector(jumpToFirstPageAfterDelay) withObject : nil afterDelay : 0.25];
   }
}

//________________________________________________________________________________
- (void) jumpToLastPageAfterDelay
{
   if (const NSUInteger nPages = pageView.numberOfPages) {
      if (pageView.activePage != nPages - 1) {
         //1. Set the page view/scroll view _without_ animation.
         pageView.activePage = nPages - 1;
         if (scroll.contentSize.width > scroll.frame.size.width)
            [scroll setContentOffset : CGPointMake(scroll.contentSize.width - scroll.frame.size.width, 0.f) animated : NO];
         //2. Inform the delegate (so that it can switch pages).
         [delegate pageControlSelectedPage : self];
      }
   }
}

//________________________________________________________________________________
- (void) jumpToLastPage
{
   if (animating)
      return;

   if (!delegate || ![delegate respondsToSelector  : @selector(pageControlSelectedPage:)])
      return;

   if (const NSUInteger nPages = pageView.numberOfPages) {
      if (pageView.activePage != nPages - 1)
         [self performSelector : @selector(jumpToLastPageAfterDelay) withObject : nil afterDelay : 0.05f];
   }
}

//________________________________________________________________________________
- (void) jumpToPage : (UITapGestureRecognizer *) tap
{
   assert(tap != nil && "jumpToPage:, parameter 'tap' is nil");
   
   if (animating)
      return;
   
   if (!delegate || ![delegate respondsToSelector : @selector(pageControlSelectedPage:)])
      return;

   CGPoint tapPoint = [tap locationInView : scroll];
   tapPoint.x -= scroll.contentOffset.x;
   CGRect scrollFrame = scroll.frame;
   scrollFrame.origin = CGPoint();

   if (CGRectContainsPoint(scrollFrame, tapPoint)) {
      tapPoint.x += scroll.contentOffset.x;
      tapPoint = [tap locationInView : pageView];
      const NSUInteger newPage = NSUInteger(tapPoint.x / [CAPPPageView defaultCellWidth]);

      if (newPage != pageView.activePage) {
         [NSObject cancelPreviousPerformRequestsWithTarget : self];
         pageView.activePage = newPage;
         [delegate pageControlSelectedPage : self];//Delegate will probably disable its own user interactions now.
         [self adjustOffsetAnimated];
      }
   }
}

@end
