//
//  CAPPTiledPageViewController.m
//  CERN
//
//  Created by Timur Pocheptsov on 18/12/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <cassert>

#import "CAPPTiledPageViewController.h"
#import "ECSlidingViewController.h"
#import "DeviceCheck.h"

@implementation CAPPTiledPageViewController {
   NSUInteger pageBeforeRotation;//To adjust a scroll view. TODO: check if a really need this.
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

      delayedRefresh = NO;
   }
   
   return self;
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
      for (NSUInteger i = 0; i < nPages; ++i) {
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
#warning "tile page view controller: refreshAfterDelay, TO BE IMPLEMENTED"
}

#pragma mark - UIScrollViewDelegate, page management, etc.

//________________________________________________________________________________________
- (void) scrollViewDidEndDecelerating : (UIScrollView *) scrollView
{
#pragma unused(scrollView)
   if (nPages > 3) {
      [self adjustPages];
      self.pageControl.activePage = currPage.pageNumber;
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

#pragma mark - Device orientation changes.

//________________________________________________________________________________________
- (BOOL) shouldAutorotate
{
   //We do not rotate if flip animation is still active.
#warning "shouldAutorotate, TO BE IMPLEMENTED"
   return !self.pageControl.animating;
}

//________________________________________________________________________________________
- (void) willRotateToInterfaceOrientation : (UIInterfaceOrientation) toInterfaceOrientation duration : (NSTimeInterval) duration
{
#pragma unused(toInterfaceOrientation, duration)

   if (!nPages)
      return;

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

@end
