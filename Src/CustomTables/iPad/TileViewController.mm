#import <algorithm>
#import <cstdlib>

#import <QuartzCore/QuartzCore.h>

#import "TileViewController.h"

#import "ECSlidingViewController.h"

@implementation TileViewController {
   NSUInteger nPages;

   NSUInteger pageBeforeRotation;

   BOOL viewDidAppear;
}

#pragma mark - Lifecycle.

//________________________________________________________________________________________
- (void) doInitController
{
   //Shared method for different "ctors".
   dataItems = nil;
   leftPage = nil;
   currPage = nil;
   rightPage = nil;

   nPages = 0;
   pageBeforeRotation = 0;
   viewDidAppear = NO;
}

//________________________________________________________________________________________
- (id) initWithCoder : (NSCoder *) aDecoder
{
   if (self = [super initWithCoder : aDecoder]) {
      [self doInitController];      
   }

   return self;
}

//________________________________________________________________________________________
- (void) viewDidLoad
{
   [super viewDidLoad];
   scrollView.checkDragging = YES;
}

//________________________________________________________________________________________
- (void) viewWillAppear : (BOOL) animated
{
   //TODO: find a better ("idiomatic") solution for this problem.
   if (nPages) {
      //it can happen, that we have a wrong geometry: detail view
      //controller was pushed on a stack, we rotate a device and press
      //a 'back' button. geometry is wrong now.
      if (currPage && currPage.frame.size.width) {
         const CGRect currentFrame = self.view.frame;
         if (currentFrame.size.width != currPage.frame.size.width)
            [self layoutPages : YES];
      }
   }
}

#pragma mark - Layout the "pages".

//________________________________________________________________________________________
- (void) layoutPages : (BOOL) layoutTiles
{
   if (!nPages)
      return;
   
   CGRect currentFrame = self.view.frame;
   currentFrame.origin = CGPoint();

   if (nPages <= 3) {
      UIView<TiledPage> * const pages[3] = {leftPage, currPage, rightPage};
      //Do not do any magic, we have only <= 3 pages.
      for (NSUInteger i = 0; i < nPages; ++i) {
         pages[i].frame = currentFrame;
         if (layoutTiles)
            [pages[i] layoutTiles];
         currentFrame.origin.x += currentFrame.size.width;
      }
   } else {
      currentFrame.origin.x = currPage.pageNumber * currentFrame.size.width;
      currPage.frame = currentFrame;
      
      CGRect leftFrame = currentFrame;
      if (currPage.pageNumber)
         leftFrame.origin.x -= leftFrame.size.width;
      else
         leftFrame.origin.x += 2 * leftFrame.size.width;
      
      leftPage.frame = leftFrame;
      
      CGRect rightFrame = currentFrame;
      if (currPage.pageNumber + 1 < nPages)
         rightFrame.origin.x += rightFrame.size.width;
      else
         rightFrame.origin.x -= 2 * rightFrame.size.width;
      
      rightPage.frame = rightFrame;
      
      if (layoutTiles) {
         [leftPage layoutTiles];
         [currPage layoutTiles];
         [rightPage layoutTiles];
      }
   }
   
   [scrollView setContentSize : CGSizeMake(currentFrame.size.width * nPages, currentFrame.size.height)];
}

#pragma mark - Device orientation changes.

//________________________________________________________________________________________
- (void) willRotateToInterfaceOrientation : (UIInterfaceOrientation) toInterfaceOrientation duration : (NSTimeInterval) duration
{
   pageBeforeRotation = NSUInteger(scrollView.contentOffset.x / scrollView.frame.size.width);
}


//________________________________________________________________________________________
- (void) willAnimateRotationToInterfaceOrientation : (UIInterfaceOrientation) toInterfaceOrientation duration : (NSTimeInterval) duration
{
   if (!nPages)
      return;

   [scrollView setContentOffset : CGPointMake(pageBeforeRotation * self.view.frame.size.width, 0.f) animated : NO];

   if (nPages <= 3) {
      UIView<TiledPage> * const pages[3] = {leftPage, currPage, rightPage};
      
      if (pageBeforeRotation)
         pages[pageBeforeRotation - 1].hidden = YES;
      if (pageBeforeRotation + 1 < nPages)
         pages[pageBeforeRotation + 1].hidden = YES;

      [self layoutPages : YES];

      [pages[pageBeforeRotation] explodeTiles : toInterfaceOrientation];
      [pages[pageBeforeRotation] collectTilesAnimatedForOrientation : toInterfaceOrientation from : CACurrentMediaTime() + duration withDuration : 0.5f];
   } else {
      leftPage.hidden = YES;
      rightPage.hidden = YES;

      [self layoutPages : YES];

      [currPage explodeTiles : toInterfaceOrientation];
      [currPage collectTilesAnimatedForOrientation : toInterfaceOrientation from : CACurrentMediaTime() + duration withDuration : 0.5f];
   }
}

//________________________________________________________________________________________
- (void) didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
   if (!nPages)
      return;

   if (nPages <= 3) {
      UIView<TiledPage> * const pages[3] = {leftPage, currPage, rightPage};
      if (pageBeforeRotation)
         pages[pageBeforeRotation - 1].hidden = NO;
      if (pageBeforeRotation + 1 < nPages)
         pages[pageBeforeRotation + 1].hidden = NO;
   } else {
      leftPage.hidden = NO;
      rightPage.hidden = NO;
   }
}

#pragma mark - Sliding view.
//________________________________________________________________________________________
- (void) revealMenu : (id) sender
{
   [self.slidingViewController anchorTopViewTo : ECRight];
}

#pragma mark - Aux.

//________________________________________________________________________________________
- (void) removeAllPages
{
   if (leftPage.superview)
      [leftPage removeFromSuperview];
   if (currPage.superview)
      [currPage removeFromSuperview];
   if (rightPage.superview)
      [rightPage removeFromSuperview];
}

//________________________________________________________________________________________
- (void) setPagesData
{
   //Let's define an image layout for a tile.
   
   //TODO: setPagesData will be also in feed tile view controller - to create tiles layout.
   
   if ((nPages = [self numberOfPages])) {
      //Let's create tiled view now.
      UIView<TiledPage> * pages[3] = {};
      if (nPages <= 3)
         pages[0] = leftPage, pages[1] = currPage, pages[2] = rightPage;
      else
         pages[0] = currPage, pages[1] = rightPage, pages[2] = leftPage;

      for (NSUInteger pageIndex = 0, currentItem = 0, e = std::min((int)nPages, 3); pageIndex < e; ++pageIndex) {
         UIView<TiledPage> * const page = pages[pageIndex];
         page.pageNumber = pageIndex;
         currentItem += [page setPageItems : dataItems startingFrom : currentItem];
         if (!page.superview)
            [scrollView addSubview : page];
      }

      [self layoutPages : YES];
      [scrollView setContentOffset : CGPointMake(0.f, 0.f)];
      //The first page is visible now, let's download ... IMAGES NOW!!! :)
      //TODO: in "cached" mode should do nothing.
      [self loadVisiblePageData];
   } else
      [self removeAllPages];
}

//________________________________________________________________________________________
- (void) adjustPages
{
   assert(nPages > 3 && "adjustPages, nPages must be > 3");
   
   const NSUInteger newCurrentPageIndex = NSUInteger(scrollView.contentOffset.x / scrollView.frame.size.width);
   if (newCurrentPageIndex == currPage.pageNumber)
      return;
   
   if (newCurrentPageIndex > currPage.pageNumber) {
      //We scrolled to the left.
      //The old 'current' becomes the new 'left'.
      //The old 'right' becomes the new 'current'.
      //The old 'left' becomes the new 'right' and we either have to set this the page or not.

      const bool leftEdge = !currPage.pageNumber;
      UIView<TiledPage> * const oldLeft = leftPage;
      leftPage = currPage;
      currPage = rightPage;
      rightPage = oldLeft;

      if (newCurrentPageIndex + 1 < nPages && !leftEdge) {
         //Set the frame first.
         CGRect frame = rightPage.frame;
         frame.origin.x = currPage.frame.origin.x + frame.size.width;
         rightPage.frame = frame;
         //Set the data now.
         [rightPage setPageItems : dataItems startingFrom : currPage.pageRange.location + currPage.pageRange.length];
         [rightPage layoutTiles];
      } 
   } else {
      //We scrolled to the right.
      //The old 'current' becomes the new 'right.
      //The old 'left' becomes the new 'current'.
      //The old 'right' becomes the new 'left' and we either have to set this page or not.
      
      const bool rightEdge = currPage.pageNumber + 1 == nPages;
      UIView<TiledPage> * const oldRight = rightPage;
      rightPage = currPage;
      currPage = leftPage;
      leftPage = oldRight;
      
      if (newCurrentPageIndex && !rightEdge) {
         CGRect frame = leftPage.frame;
         frame.origin.x = currPage.frame.origin.x - frame.size.width;
         leftPage.frame = frame;
         //Set the data now.
         const NSRange range = [leftPage.class suggestRangeBackward : dataItems endingWith : currPage.pageRange.location];
         [leftPage setPageItems : dataItems startingFrom : range.location];
         [leftPage layoutTiles];
      }
   }
   
   currPage.pageNumber = newCurrentPageIndex;
}

//________________________________________________________________________________________
- (NSUInteger) numberOfPages
{
   NSUInteger pages = 0;
   NSRange range = {};
   while (range.location + range.length < dataItems.count) {
      ++pages;
      range = [leftPage.class suggestRangeForward : dataItems startingFrom : range.location + range.length];
   }

   return pages;

}

//________________________________________________________________________________________
- (NSRange) findItemRangeForPage : (NSUInteger) page
{
   assert(page < nPages && "findItemRangeForPage:, parameter 'page' is out of bounds");
   
   //Ugly, inefficient, but .. we never have a huge number of pages :)
   NSRange range = {};
   for (NSUInteger i = 0; i <= page; ++i)
      range = [leftPage.class suggestRangeForward : dataItems startingFrom : range.location + range.length];
   
   return range;
}

//________________________________________________________________________________________
-(void) loadVisiblePageData
{
   //Noop here.
}

@end
