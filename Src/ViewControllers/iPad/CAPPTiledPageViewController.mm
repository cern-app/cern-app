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
      if (nPages > 1) {
         assert(prevPage != nil && "setPagesData, prevPage is nil");
         
         const NSRange pageRange = [self findItemRangeForPage : 1];
         [prevPage setPageItems : dataItems startingFrom : pageRange.location];
         prevPage.pageNumber = 1;
      }

      if (nPages > 2) {
         assert(nextPage != nil && "setPagesData, nextPage is nil");
         const NSRange pageRange = [self findItemRangeForPage : nPages - 1];
         [nextPage setPageItems : dataItems startingFrom : pageRange.location];
         nextPage.pageNumber = nPages - 1;
      }

      assert(currPage != nil && "setPagesData, currPage is nil");
      [currPage setPageItems : dataItems startingFrom : 0];
      currPage.pageNumber = 0;
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
   //TODO: to be implemented.
#warning "tile page view controller: layoutPages:, TO BE IMPLEMENTED"
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

#pragma mark - Device orientation changes.

//________________________________________________________________________________________
- (BOOL) shouldAutorotate
{
   //We do not rotate if flip animation is still active.
#warning "tile page view controller: shouldAutorotate, TO BE IMPLEMENTED"
   return YES;
}

//________________________________________________________________________________________
- (void) willAnimateRotationToInterfaceOrientation : (UIInterfaceOrientation) toInterfaceOrientation duration : (NSTimeInterval) duration
{
#pragma unused(toInterfaceOrientation, duration)
#warning "tile page view controller: willAnimateRotationToInterfaceOrientation:duration:, TO BE IMPLEMENTED"
}

//________________________________________________________________________________________
- (void) didRotateFromInterfaceOrientation : (UIInterfaceOrientation) fromInterfaceOrientation
{
#warning "tile page view controller: didRotateFromInterfaceOrientation:, TO BE IMPLEMENTED"
   //TODO: to be implemented.
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
