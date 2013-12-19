//
//  CAPPTiledPageViewController.m
//  CERN
//
//  Created by Timur Pocheptsov on 18/12/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//
#import <algorithm>
#import <cassert>
#import <cmath>

#import "CAPPTiledPageViewController.h"
#import "ECSlidingViewController.h"
#import "SlideScrollView.h"
#import "DeviceCheck.h"

@implementation CAPPTiledPageViewController {
   NSUInteger pageBeforeRotation;//To adjust a scroll view. TODO: check if a really need this.
   BOOL rotating;
}

@synthesize pageControl, parentScroll, noConnectionHUD, spinner;

//________________________________________________________________________________________
- (instancetype) initWithCoder : (NSCoder *) aDecoder
{
   if (self = [super initWithCoder : aDecoder]) {
      dataItems = nil;
      prevPage = nil;
      currPage = nil;
      nextPage = nil;

      noConnectionHUD = nil;
      spinner = nil;

      nPages = 0;
      pageBeforeRotation = 0;
      rotating = NO;

      delayedRefresh = NO;
   }
   
   return self;
}

//________________________________________________________________________________________
- (void) viewDidLoad
{
   [super viewDidLoad];
   parentScroll.checkDragging = YES;
   parentScroll.decelerationRate = UIScrollViewDecelerationRateFast;
   pageControl.delegate = self;
}

//________________________________________________________________________________________
- (void) viewDidAppear : (BOOL) animated
{
   //TODO: this will change in a future.

   if (CernAPP::SystemVersionGreaterThanOrEqualTo(@"7.0")) {
#ifdef __IPHONE_7_0
      self.navigationController.interactivePopGestureRecognizer.enabled = NO;
#endif
   }
}

#pragma mark - Layout the "pages".

//________________________________________________________________________________________
- (void) setPagesData
{
   if ((nPages = [self numberOfPages])) {
      assert(currPage != nil && "setPagesData, currPage is nil");
      [currPage setPageItems : dataItems startingFrom : 0];
      currPage.pageNumber = 0;//TODO: get rid of pageNumber.
   
      if (nPages > 1) {
         assert(nextPage != nil && "setPagesData, nextPage is nil");

         const NSRange pageRange = [self findItemRangeForPage : 1];
         [nextPage setPageItems : dataItems startingFrom : pageRange.location];
         nextPage.pageNumber = 1;
      }
      
      if (nPages > 2) {
         assert(prevPage != nil && "setPagesData, prevPage is nil");
         const NSRange pageRange = [self findItemRangeForPage : 2];
         [prevPage setPageItems : dataItems startingFrom : pageRange.location];
         prevPage.pageNumber = 2;
      }
   }
}

//________________________________________________________________________________________
-(void) loadVisiblePageData
{
   //Noop, to be overriden.
}

//________________________________________________________________________________________
- (void) layoutPages : (BOOL) layoutTiles
{
   //Set the geometry for page views (and their subviews).
   if (!nPages)
      return;
   
   CGRect currentFrame = self.parentScroll.frame;
   currentFrame.origin = CGPoint();
   
   if (nPages <= 3 || !currPage.pageNumber) {
      UIView<TiledPage> * pages[3] = {currPage, nextPage, prevPage};
      //No magic, we have only <= 3 pages.
      const NSUInteger end = std::min(nPages, NSUInteger(3));
      for (NSUInteger i = 0; i < end; ++i) {
         pages[i].frame = currentFrame;
         if (layoutTiles)
            [pages[i] layoutTiles];
         currentFrame.origin.x += currentFrame.size.width;
      }
   } else {
      currentFrame.origin.x = currPage.pageNumber * currentFrame.size.width;
      currPage.frame = currentFrame;

      currentFrame.origin.x -= currentFrame.size.width;
      prevPage.frame = currentFrame;
      
      if (currPage.pageNumber + 1 < nPages)
         currentFrame.origin.x += 2 * currentFrame.size.width;
      else
         currentFrame.origin.x -= currentFrame.size.width;
      
      nextPage.frame = currentFrame;
      
      if (layoutTiles) {
         [prevPage layoutTiles];
         [nextPage layoutTiles];
         [currPage layoutTiles];
      }
   }
   
   [parentScroll setContentSize : CGSizeMake(currentFrame.size.width * nPages, currentFrame.size.height)];
}

//________________________________________________________________________________________
- (NSRange) findItemRangeForPage : (NSUInteger) page
{
   assert(page < nPages && "findItemRangeForPage:, parameter 'page' is out of bounds");

   NSRange range = {};
   for (NSUInteger i = 0; i <= page; ++i)
      range = [currPage.class suggestRangeForward : dataItems startingFrom : range.location + range.length];
   
   return range;
}

//________________________________________________________________________________________
- (void) refreshAfterDelay
{
#warning "refreshAfterDelay, TO BE IMPLEMENTED"
}

#pragma mark - UIScrollViewDelegate, page management, etc.

//________________________________________________________________________________________
- (void) scrollViewDidEndDecelerating : (UIScrollView *) scrollView
{
#pragma unused(scrollView)

   const bool supportsZoom = [currPage respondsToSelector : @selector(unscale)];
   
   pageControl.userInteractionEnabled = YES;

   if (supportsZoom) {
      [currPage unscale];
      if (nPages > 1)
         [nextPage unscale];
      if (nPages > 2)
         [prevPage unscale];
   }
   
   if (nPages > 3) {
      [self adjustPages];
      if (currPage.pageNumber != pageControl.activePage) {
         parentScroll.userInteractionEnabled = NO;
         pageControl.activePage = currPage.pageNumber;
      }
   } else {
      const NSUInteger currPageIndex = NSUInteger(parentScroll.contentOffset.x / parentScroll.frame.size.width);
      if (currPageIndex != pageControl.activePage) {
         parentScroll.userInteractionEnabled = NO;
         pageControl.activePage = currPageIndex;
      }
   }
}

//________________________________________________________________________________________
- (void) adjustPages
{
   assert(nPages > 3 && "adjustPages, nPages must be > 3");
   assert(dataItems != nil && "adjustPages, dataItems is nil");

   const NSUInteger newCurrentPageIndex = NSUInteger(self.parentScroll.contentOffset.x / self.parentScroll.frame.size.width);
   if (newCurrentPageIndex == currPage.pageNumber)
      return;

   if (newCurrentPageIndex > currPage.pageNumber) {
      //We scrolled to the left.
      //The old 'curr' becomes the new 'prev'.
      //The old 'next' becomes the new 'curr'.
      //The old 'prev' becomes the new 'right' and we either have to load this page or not.

       const bool leftEdge = !currPage.pageNumber;
       UIView<TiledPage> * const oldPrev = prevPage;
       prevPage = currPage;
       currPage = nextPage;
       nextPage = oldPrev;

       if (newCurrentPageIndex + 1 < nPages && !leftEdge) {
         //Set the frame first.
         CGRect frame = currPage.frame;
         frame.origin.x += frame.size.width;
         nextPage.frame = frame;
         //Set the data now (we have to load one more page).
         const NSRange rangeToLoad = [self findItemRangeForPage : newCurrentPageIndex + 1];
         assert(rangeToLoad.location < dataItems.count && "adjustPages, new page range is out of bounds");
         [nextPage setPageItems : dataItems startingFrom : rangeToLoad.location];
         [nextPage layoutTiles];
         nextPage.pageNumber = newCurrentPageIndex + 1;
      }
   } else {
      //We scrolled to the right.
      //The old 'curr' becomes the new 'next'.
      //The old 'prev' becomes the new 'curr'.
      //The old 'next' becomes the new 'prev' and we either have to load this page or not.
      const bool rightEdge = currPage.pageNumber + 1 == nPages;
      
      UIView<TiledPage> *const oldNext = nextPage;
      nextPage = currPage;
      currPage = prevPage;
      prevPage = oldNext;

      if (newCurrentPageIndex && !rightEdge) {
          CGRect frame = currPage.frame;
         frame.origin.x -= frame.size.width;
         prevPage.frame = frame;
         //Set the data now.
         const NSRange rangeToLoad = [self findItemRangeForPage : newCurrentPageIndex - 1];
         assert(rangeToLoad.location < dataItems.count && "adjustPages, new page range is out of bounds");
         [prevPage setPageItems : dataItems startingFrom : rangeToLoad.location];
         [prevPage layoutTiles];
         prevPage.pageNumber = newCurrentPageIndex - 1;
      }
   }
}

//________________________________________________________________________________________
- (void) scrollViewDidEndDragging : (UIScrollView *) scrollView willDecelerate : (BOOL) decelerate
{
   if (!decelerate)
      [self scrollViewDidEndDecelerating : scrollView];
}

//_______________________________________________________________________
-(void) scrollViewDidScroll : (UIScrollView *) scrollView
{
#pragma unused(scrollView)

   if (rotating)
      return;

   //while we're scrolling, it's not good to navigate via pageControl at the same time.
   pageControl.userInteractionEnabled = NO;
   //

   if (![currPage respondsToSelector : @selector(setScaleFactor:)])
      return;

   //We map [0 1] from offset to [0.7, 1.] scale factor.
   const CGFloat off = currPage.frame.origin.x - parentScroll.contentOffset.x;
   if (!off)
      return;
   //scale down the current page, scale up the next.
   
   CGFloat scaleFactor = (parentScroll.frame.size.width - std::abs(off)) / parentScroll.frame.size.width;
   scaleFactor = scaleFactor * 0.3f + 0.7f;
   [currPage setScaleFactor : scaleFactor];
   
   scaleFactor = std::abs(off) / scrollView.frame.size.width;
   scaleFactor = scaleFactor * 0.3f + 0.7f;
   if (off < 0.f)
      [nextPage setScaleFactor : scaleFactor];
   else
      [prevPage setScaleFactor : scaleFactor];
}

#pragma mark - Device orientation changes.

//________________________________________________________________________________________
- (BOOL) shouldAutorotate
{
   //We do not rotate if flip animation is still active.
   return !rotating && !pageControl.animating;
}

//________________________________________________________________________________________
- (void) willRotateToInterfaceOrientation : (UIInterfaceOrientation) toInterfaceOrientation duration : (NSTimeInterval) duration
{
#pragma unused(toInterfaceOrientation, duration)

   if (!nPages)
      return;

   rotating = YES;
   pageBeforeRotation = NSUInteger(parentScroll.contentOffset.x / parentScroll.frame.size.width);
}

//________________________________________________________________________________________
- (void) willAnimateRotationToInterfaceOrientation : (UIInterfaceOrientation) toInterfaceOrientation duration : (NSTimeInterval) duration
{
#pragma unused(toInterfaceOrientation, duration)

   if (!nPages)
      return;
   
   [parentScroll setContentOffset : CGPointMake(currPage.pageNumber * self.view.frame.size.width, 0.f) animated : NO];

   if (nPages <= 3) {
      UIView<TiledPage> * const pages[3] = {currPage, nextPage, prevPage};

      if (pageBeforeRotation)
         pages[pageBeforeRotation - 1].hidden = YES;
      if (pageBeforeRotation + 1 < nPages)
         pages[pageBeforeRotation + 1].hidden = YES;

      [self layoutPages : YES];
      [pages[pageBeforeRotation] explodeTiles : toInterfaceOrientation];
      [pages[pageBeforeRotation] collectTilesAnimatedForOrientation : toInterfaceOrientation from : CACurrentMediaTime() + duration withDuration : 0.5f];
   } else {
      prevPage.hidden = YES;
      nextPage.hidden = YES;

      [self layoutPages : YES];

      [currPage explodeTiles : toInterfaceOrientation];
      [currPage collectTilesAnimatedForOrientation : toInterfaceOrientation from : CACurrentMediaTime() + duration withDuration : 0.5f];
   }
}

//________________________________________________________________________________________
- (void) didRotateFromInterfaceOrientation : (UIInterfaceOrientation) fromInterfaceOrientation
{
#pragma unused(fromInterfaceOrientation)

   rotating = NO;

   if (!nPages)
      return;
   
   prevPage.hidden = NO;
   nextPage.hidden = NO;
   currPage.hidden = NO;
}

#pragma mark - Sliding view.
//________________________________________________________________________________________
- (void) revealMenu : (id) sender
{
#pragma unused(sender)

   [self.slidingViewController anchorTopViewTo : ECRight];
}

#pragma mark - Misc.

//________________________________________________________________________________________
- (BOOL) canShowAlert
{
   return YES;//to be overriden.
}

#pragma mark - Aux. methods.

//________________________________________________________________________________________
- (NSUInteger) numberOfPages
{
   assert(currPage != nil &&
          "numberOfPages, currPage is nil, the paging algorithm is unknown");

   NSUInteger pages = 0;
   NSRange range = {};
   while (range.location + range.length < dataItems.count) {
      ++pages;
      range = [currPage.class suggestRangeForward : dataItems startingFrom : range.location + range.length];
   }

   return pages;
}

#pragma mark - CAPPPageControllerDelegate.

//________________________________________________________________________________________
- (void) jumpToFirstPage
{
   pageControl.userInteractionEnabled = NO;
   
   [self setPagesData];
   parentScroll.delegate = nil;//I do not want to receive didScroll.
   [parentScroll setContentOffset : CGPoint() animated : NO];
   parentScroll.delegate = self;
   [self layoutPages : YES];

   pageControl.userInteractionEnabled = YES;
}

//________________________________________________________________________________________
- (void) jumpToLastPage
{
   pageControl.userInteractionEnabled = NO;

   if (nPages <= 3) {
      //Simple case.
      parentScroll.delegate = nil;
      [parentScroll setContentOffset : CGPointMake(2 * parentScroll.frame.size.width, 0.f) animated : NO];
      parentScroll.delegate = self;
   } else {
      UIView<TiledPage> * const oldPrev = prevPage;
      prevPage = currPage;
      currPage = nextPage;
      nextPage = oldPrev;

      [currPage setPageItems : dataItems startingFrom : [self findItemRangeForPage : nPages - 1].location];
      currPage.pageNumber = nPages - 1;
      [currPage layoutTiles];
      
      CGRect frame = currPage.frame;
      frame.origin.x = parentScroll.contentSize.width - frame.size.width;
      currPage.frame = frame;
      
      [prevPage setPageItems : dataItems startingFrom : [self findItemRangeForPage : nPages - 2].location];
      prevPage.pageNumber = nPages - 2;
      [prevPage layoutTiles];
      frame.origin.x -= frame.size.width;
      prevPage.frame = frame;
      
      [nextPage setPageItems : dataItems startingFrom : [self findItemRangeForPage : nPages - 3].location];
      nextPage.pageNumber = nPages - 3;
      [nextPage layoutTiles];
      frame.origin.x -= frame.size.width;
      nextPage.frame = frame;
      
      parentScroll.delegate = nil;
      [parentScroll setContentOffset : CGPointMake(parentScroll.contentSize.width - frame.size.width, 0.f) animated : NO];
      parentScroll.delegate = self;
   }
   
   pageControl.userInteractionEnabled = YES;
}

//________________________________________________________________________________________
- (void) jumpToActivePage
{
   //0 and nPages - 1 is processed in other methods.
   assert(pageControl.activePage != 0 && pageControl.activePage != nPages - 1 &&
          "jumpToActivePage, called for the first or the last page as active");


   if (!pageControl.activePage)
      return [self jumpToFirstPage];

   if (pageControl.activePage == nPages - 1)
      return [self jumpToLastPage];
   
   pageControl.userInteractionEnabled = NO;
   
   if (nPages <= 3) {
      //Simple case.
      parentScroll.delegate = nil;
      [parentScroll setContentOffset : CGPointMake(parentScroll.frame.size.width * pageControl.activePage, 0.f) animated : NO];
      parentScroll.delegate = self;
   } else {
      [currPage setPageItems : dataItems startingFrom : [self findItemRangeForPage : pageControl.activePage].location];
      currPage.pageNumber = pageControl.activePage;
      [currPage layoutTiles];
      
      CGRect frame = currPage.frame;
      frame.origin.x = pageControl.activePage * frame.size.width;
      currPage.frame = frame;
      
      [prevPage setPageItems : dataItems startingFrom : [self findItemRangeForPage : pageControl.activePage - 1].location];
      prevPage.pageNumber = pageControl.activePage - 1;
      [prevPage layoutTiles];
      frame.origin.x -= frame.size.width;
      prevPage.frame = frame;
      
      [nextPage setPageItems : dataItems startingFrom : [self findItemRangeForPage : pageControl.activePage + 1].location];
      nextPage.pageNumber = pageControl.activePage + 1;
      [nextPage layoutTiles];
      frame.origin.x += 2 * frame.size.width;
      nextPage.frame = frame;
      
      parentScroll.delegate = nil;
      [parentScroll setContentOffset:CGPointMake(currPage.frame.origin.x, 0.f) animated : NO];
      parentScroll.delegate = self;
   }
   
   pageControl.userInteractionEnabled = YES;
}

//________________________________________________________________________________________
- (void) pageControlSelectedPage : (CAPPPageControl *) control
{
#pragma unused(control)

   if (!pageControl.activePage) {
      //We reset all pages.
      [self jumpToFirstPage];
   } else if (pageControl.activePage == nPages - 1) {
      //We reset all pages.
      [self jumpToLastPage];
   } else {
      //We have to wait: first, page control must adjust its offset (probably, with an animation);
      //second, we switch pages accordingly.
      parentScroll.hidden = YES;
      parentScroll.userInteractionEnabled = NO;
   }
}

//________________________________________________________________________________________
- (void) pageControlDidEndAnimating : (CAPPPageControl *) control
{
#pragma unused(control)

   parentScroll.userInteractionEnabled = YES;
   parentScroll.hidden = NO;
   
   NSUInteger currPageIndex = 0;
   if (nPages <= 3)
      currPageIndex = NSUInteger(parentScroll.contentOffset.x / parentScroll.frame.size.width);
   else
      currPageIndex = currPage.pageNumber;

   if (currPageIndex != pageControl.activePage)
      [self jumpToActivePage];
}

@end
