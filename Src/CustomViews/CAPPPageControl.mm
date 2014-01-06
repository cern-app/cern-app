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
}

#pragma mark - Geometry and layout.

//________________________________________________________________________________
- (void) layoutSubviews : (CGRect) frame
{
   //What about animation???
   assert(animating == NO && "layoutSubviews:, called while an animation is active");

   //"Hint" for a pageView's frame.
   CGRect pageViewFrame = frame;
   pageViewFrame.origin = CGPoint();
   //Right label with such a hint.

   if (pageView.numberOfPages) {
      const CGFloat visibleW = NSUInteger(frame.size.width / [CAPPPageView defaultCellWidth]) * [CAPPPageView defaultCellWidth];
      pageView.frame = CGRectMake(0.f, 0.f, [CAPPPageView defaultCellWidth] * pageView.numberOfPages, frame.size.height);
      if (pageView.frame.size.width < visibleW)
         scroll.frame = CGRectMake(frame.size.width / 2 - pageView.frame.size.width / 2, 0.f, pageView.frame.size.width, frame.size.height);
      else
         scroll.frame = CGRectMake(frame.size.width / 2 - visibleW / 2, 0.f, visibleW, frame.size.height);
      scroll.contentSize = pageView.frame.size;
   } else {
      pageView.frame = CGRectMake(0.f, 0.f, frame.size.width, frame.size.height);
      scroll.frame = pageView.frame;
      scroll.contentSize = frame.size;
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
   scroll.hidden = nPages == 1;
   
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

@end
