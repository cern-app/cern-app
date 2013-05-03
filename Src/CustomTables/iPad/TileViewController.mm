#import <algorithm>
#import <cstdlib>

#import <QuartzCore/QuartzCore.h>

#import "ECSlidingViewController.h"
#import "TileViewController.h"
#import "FlipView.h"

using namespace FlipAnimation;

@implementation TileViewController {
   NSUInteger pageBeforeRotation;

   UIPanGestureRecognizer *panGesture;
   BOOL viewDidAppear;
}

#pragma mark - Lifecycle.

//________________________________________________________________________________________
- (void) doInitTileViewController
{
   //Shared method for different "ctors".
   dataItems = nil;
   prevPage = nil;
   currPage = nil;
   nextPage = nil;

   panGesture = nil;
   panRegion = nil;

   nPages = 0;
   pageBeforeRotation = 0;
   viewDidAppear = NO;
}

//________________________________________________________________________________________
- (id) initWithCoder : (NSCoder *) aDecoder
{
   if (self = [super initWithCoder : aDecoder])
      [self doInitTileViewController];

   return self;
}

//________________________________________________________________________________________
- (void) viewDidLoad
{
   [super viewDidLoad];
   //Create the flipView and the panRegion.
   CGRect frame = self.view.frame;
   frame.origin = CGPoint();
   
   flipView = [[FlipView alloc] initWithAnimationType : AnimationType::flipHorizontal frame : frame];
   [self.view addSubview : flipView];

   panRegion = [[UIView alloc] initWithFrame : frame];
   [self.view addSubview : panRegion];
   
   panGesture = [[UIPanGestureRecognizer alloc] initWithTarget : self action : @selector(panned:)];
   panGesture.maximumNumberOfTouches = 1;
   panGesture.minimumNumberOfTouches = 1;
   [self.view addGestureRecognizer : panGesture];
   
   flipAnimator = [[AnimationDelegate alloc] initWithSequenceType : SequenceType::controlled directionType : DirectionType::forward];
   flipAnimator.transformView = flipView;
   flipAnimator.controller = self;
   flipAnimator.perspectiveDepth = 2000;
  
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
         if (currentFrame.size.width != currPage.frame.size.width) {
            [self layoutPages : YES];
            [self layoutFlipView];
            [self layoutPanRegion];
         }
      }
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
   //Noop here.
}

//________________________________________________________________________________________
- (void) layoutPages : (BOOL) layoutTiles
{
   if (!nPages)
      return;
   
   CGRect currentFrame = self.view.frame;
   currentFrame.origin = CGPoint();
   
   if (nPages > 1) {
      prevPage.frame = currentFrame;
      if (layoutTiles)
         [prevPage layoutTiles];
   }
   
   if (nPages > 2) {
      nextPage.frame = currentFrame;
      if (layoutTiles)
         [nextPage layoutTiles];
   }
   
   currPage.frame = currentFrame;
   if (layoutTiles)
      [currPage layoutTiles];
}

//________________________________________________________________________________________
- (void) layoutFlipView
{
   assert(flipView != nil && "layoutFlipView, flipView is nil");

   CGRect frame = self.view.frame;
   frame.origin = CGPoint();
   
   flipView.frame = frame;
   [flipView removeAllFrames];
   [flipView setFrameGeometry : frame.size];
   
   if (nPages > 1)
      [flipView addFrame : prevPage];
   
   if (nPages > 2)
      [flipView addFrame : nextPage];

   [flipView addFrame : currPage];
}

//________________________________________________________________________________________
- (void) layoutPanRegion
{
   assert(panRegion != nil && "layoutPanRegion, panRegion is nil");

   CGRect frame = self.view.frame;
   frame.origin = CGPoint();

   panRegion.frame = frame;
}


//________________________________________________________________________________________
- (NSRange) findItemRangeForPage : (NSUInteger) page
{
   assert(page < nPages && "findItemRangeForPage:, parameter 'page' is out of bounds");
   
   //Ugly, inefficient, but .. we never have a huge number of pages :)
   NSRange range = {};
   for (NSUInteger i = 0; i <= page; ++i)
      range = [currPage.class suggestRangeForward : dataItems startingFrom : range.location + range.length];
   
   return range;
}


#pragma mark - Device orientation changes.

//________________________________________________________________________________________
- (BOOL) shouldAutorotate
{
   //We do not rotate if flip animation is still active.

   assert(flipAnimator != nil && "shouldAutorotate, flipAnimator is nil");
   return !flipAnimator.animationLock;
}

//________________________________________________________________________________________
- (void) willAnimateRotationToInterfaceOrientation : (UIInterfaceOrientation) toInterfaceOrientation duration : (NSTimeInterval) duration
{
   assert(flipAnimator.animationLock == NO &&
          "willAnimateRotationToInterfaceOrientation:duration:, flip animation is active");

   if (!nPages)
      return;

   [self layoutPages : YES];
   [currPage explodeTiles : toInterfaceOrientation];
   [currPage collectTilesAnimatedForOrientation : toInterfaceOrientation from : CACurrentMediaTime() + duration withDuration : 0.5f];
}

//________________________________________________________________________________________
- (void) didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
   if (!nPages)
      return;

   [self layoutFlipView];
   [self layoutPanRegion];
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
   if (prevPage.superview) {
      [prevPage removeFromSuperview];
      prevPage = nil;
   }
   
   if (currPage.superview) {
      [currPage removeFromSuperview];
      currPage = nil;
   }
   
   if (nextPage.superview) {
      [nextPage removeFromSuperview];
      nextPage = nil;
   }
}

//________________________________________________________________________________________
- (NSUInteger) numberOfPages
{
   assert(currPage != nil &&
          "numberOfPages, currPage is nil and thus the paging algorithm is unknown");

   NSUInteger pages = 0;
   NSRange range = {};
   while (range.location + range.length < dataItems.count) {
      ++pages;
      range = [currPage.class suggestRangeForward : dataItems startingFrom : range.location + range.length];
   }

   return pages;

}

#pragma mark - Flipboard animation.

//________________________________________________________________________________________
- (void) animationDidFinish : (int) direction
{
   assert(nPages > 1 && "animationDidFinish:, wrong number of pages");
   
   if (nPages > 3) {
      if (direction == -1) {
         //We are moving to the next page (for the flip view it's "backward" though).
         const NSUInteger pageToLoad = prevPage.pageNumber + 1 < nPages ? prevPage.pageNumber + 1 : 0;
         //curr becomes == prev
         //next becomes == curr
         //prev - new page loaded.
         UIView<TiledPage> * const oldCurr = currPage;
         UIView<TiledPage> * const oldPrev = prevPage;
         
         const NSRange newPageRange = [self findItemRangeForPage : pageToLoad];
         [nextPage setPageItems : dataItems startingFrom : newPageRange.location];
         nextPage.pageNumber = pageToLoad;
         [nextPage layoutTiles];

         prevPage = nextPage;
         nextPage = oldCurr;
         currPage = oldPrev;
         
         [flipView shiftBackwardWithNewPage : prevPage];
      } else {
         //We are moving to the previous page (and it's "forward" for the flip view).
         const NSUInteger pageToLoad = nextPage.pageNumber ? nextPage.pageNumber - 1 : nPages - 1;
         //curr becomes == next
         //prev becomes == curr
         //next - new page loaded.
         UIView<TiledPage> * const oldCurr = currPage;
         UIView<TiledPage> * const oldNext = nextPage;
         
         const NSRange newPageRange = [self findItemRangeForPage : pageToLoad];
         
         [prevPage setPageItems : dataItems startingFrom : newPageRange.location];
         prevPage.pageNumber = pageToLoad;
         [prevPage layoutTiles];

         nextPage = prevPage;
         prevPage = oldCurr;
         currPage = oldNext;
         
         [flipView shiftForwardWithNewPage : nextPage];
      }
   } else {
      //All pages are still actual, I only have to change the ordering.
      if (nPages == 2) {
         UIView<TiledPage> * const oldPrev = prevPage;
         prevPage = currPage;
         currPage = oldPrev;
      } else if (direction == -1) {
         UIView<TiledPage> * const oldNext = nextPage;
         nextPage = currPage;
         currPage = prevPage;
         prevPage = oldNext;
      } else {
         UIView<TiledPage> * const oldCurr = currPage;
         currPage = nextPage;
         nextPage = prevPage;
         prevPage = oldCurr;
      }
   }
   
   flipView.hidden = YES;

   if (!currPage.superview)
      [self.view addSubview : currPage];

   [currPage.superview bringSubviewToFront : currPage];
   [self loadVisiblePageData];
}

//________________________________________________________________________________________
- (void) animationCancelled
{
   flipView.hidden = YES;

   if (!currPage.superview)
      [self.view addSubview : currPage];

   [currPage.superview bringSubviewToFront : currPage];
}

//________________________________________________________________________________________
- (void) panned : (UIPanGestureRecognizer *) recognizer
{
   assert(recognizer != nil && "panned:, parameter 'recognizer' is nil");
   
   //TODO: this function requires tuning to avoid different bugs with
   //flip animation.

   if (nPages <= 1)
      return;

   switch (recognizer.state) {
   case UIGestureRecognizerStatePossible:
      break;
   case UIGestureRecognizerStateFailed: // cannot recognize for multi touch sequence
      break;
   case UIGestureRecognizerStateBegan:
      {
         // allow controlled flip only when touch begins within the pan region
         if (CGRectContainsPoint(panRegion.frame, [recognizer locationInView : self.view])) {
            if (flipAnimator.animationState == 0) {
               flipView.hidden = NO;
               [flipView.superview bringSubviewToFront : flipView];

               [NSObject cancelPreviousPerformRequestsWithTarget : self];
               flipAnimator.sequenceType = SequenceType::controlled;
               flipAnimator.animationLock = YES;
            }
         }
      }
      break;
   case UIGestureRecognizerStateChanged:
      {
         if (flipAnimator.animationLock) {
            switch (flipView.animationType) {
            case AnimationType::flipVertical:
               {
                  const CGFloat value = [recognizer translationInView : self.view].y;
                  [flipAnimator setTransformValue : value delegating : NO];
               }
               break;
            case AnimationType::flipHorizontal:
               {
                  const CGFloat value = [recognizer translationInView : self.view].x / 2.f;//2 is some arbitrary value here.
                  [flipAnimator setTransformValue : value delegating : NO];
               }
               break;
            default:
               break;
            }
         }
      }
      break;
   case UIGestureRecognizerStateCancelled: // cancellation touch
      break;
   case UIGestureRecognizerStateEnded:
      {
         if (flipAnimator.animationLock) {
            // provide inertia to panning gesture
            const CGFloat value = sqrtf(fabsf([recognizer velocityInView : self.view].x))/10.0f;
            [flipAnimator endStateWithSpeed : value];
         }
      }
      break;
   default:
      break;
   }
}


@end
