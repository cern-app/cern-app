#import <algorithm>
#import <cstdlib>
#import <cmath>

#import <QuartzCore/QuartzCore.h>
#import <Availability.h>

#import "ECSlidingViewController.h"
#import "TileViewController.h"
#import "CAPPPageControl.h"
#import "DeviceCheck.h"
#import "FlipView.h"

using namespace FlipAnimation;

const NSUInteger nAutoAnimationSteps = 10;

@implementation TileViewController {
   NSUInteger pageBeforeRotation;
   
   //If our evil user has too fast fingers, we should breake th ... or, I sure
   //mean we'll switch to the "automatic animation mode".
   BOOL autoFlipAnimation;
   //
   
   CGPoint panStartPoint;
   CGFloat lastTranslationX;
   CGFloat autoPanStepX;
   NSUInteger autoAnimationStep;
   
   UIImageView *flipHintView;
}

@synthesize pageControl, noConnectionHUD, spinner;

#pragma mark - Lifecycle.

//________________________________________________________________________________________
- (id) initWithCoder : (NSCoder *) aDecoder
{
   if (self = [super initWithCoder : aDecoder]) {
      dataItems = nil;
      prevPage = nil;
      currPage = nil;
      nextPage = nil;

      panGesture = nil;
      panRegion = nil;

      noConnectionHUD = nil;
      spinner = nil;

      nPages = 0;
      pageBeforeRotation = 0;
      autoFlipAnimation = NO;
      
      flipHintView = [[UIImageView alloc] initWithImage : [UIImage imageNamed : @"flip_right.png"]];
      flipHintView.hidden = YES;

      delayedFlipRefresh = NO;
      
      flipAnimator = [[AnimationDelegate alloc] initWithSequenceType : SequenceType::controlled directionType : DirectionType::forward];
   }

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
   
   //flipAnimator = [[AnimationDelegate alloc] initWithSequenceType : SequenceType::controlled directionType : DirectionType::forward];
   assert(flipAnimator != nil && "viewDidLoad, flipAnimator is not initialized properly");
   flipAnimator.transformView = flipView;
   flipAnimator.controller = self;
   flipAnimator.perspectiveDepth = 2000;
   
   //flipView is actually quite a heavy-weight thing.
   //It has a complex hierarchy of layers attached,
   //so sliding-view animation is simply killed by
   //this complexity.
   flipView.hidden = YES;
}

//________________________________________________________________________________________
- (void) viewDidAppear : (BOOL) animated
{
   if (CernAPP::SystemVersionGreaterThanOrEqualTo(@"7.0")) {
#ifdef __IPHONE_7_0
      self.navigationController.interactivePopGestureRecognizer.enabled = NO;
#endif
   }
   
   [self.slidingViewController.panGesture requireGestureRecognizerToFail : panGesture];
}

//________________________________________________________________________________________
- (void) viewWillAppear : (BOOL) animated
{
   //TODO: find a better ("idiomatic") solution for this problem.
   [super viewWillAppear : animated];


   //it can happen, that we have a wrong geometry: detail view
   //controller was pushed on a stack, we rotate a device and press
   //a 'back' button. geometry is wrong now.
   if (nPages) {
      if (currPage && currPage.frame.size.width) {
         const CGRect currFrame = currPage.frame;// self.view.frame;
         const UIInterfaceOrientation currentOrientation = [[UIApplication sharedApplication] statusBarOrientation];
         bool layoutBroken = false;
         if (UIInterfaceOrientationIsLandscape(currentOrientation)) {
            if (currFrame.size.width < currFrame.size.height) {
               //Nice! Thank you, Apple's engineers!
               self.view.frame = CGRectMake(0.f, 0.f, 1024.f, 704.f);
               layoutBroken = true;
            }
         } else {
            if (currFrame.size.width > currFrame.size.height) {
               //Nice! Thank you, Apple's engineers!
               self.view.frame = CGRectMake(0.f, 0.f, 768.f, 960.f);
               layoutBroken = true;
            }
         }

         if (layoutBroken) {
            [self layoutPages : YES];
            [self layoutFlipView];
            [self layoutPanRegion];
            [self fixFlipHintGeometry];
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
   //Set the geometry for page views (and their subviews).
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
   if (layoutTiles)//if nPages == 0 I have no tiles.
      [currPage layoutTiles];
}

//________________________________________________________________________________________
- (void) layoutFlipView
{
   assert(flipView != nil && "layoutFlipView, flipView is nil");

   //Set the correct geometry for a flip view and re-create snapshots for pages.

   CGRect frame = self.view.frame;
   frame.origin = CGPoint();
   
   flipView.frame = frame;
   [flipView removeAllFrames];
   [flipView setFrameGeometry : frame.size];
   
   if (nPages > 1)
      [flipView addFrame : prevPage];
   
   if (nPages > 2)
      [flipView addFrame : nextPage];

   if (nPages)
      [flipView addFrame : currPage];
}

//________________________________________________________________________________________
- (void) layoutPanRegion
{
   //Geometry for a pan region view.
   assert(panRegion != nil && "layoutPanRegion, panRegion is nil");

   CGRect frame = self.view.frame;
   frame.origin = CGPoint();

   panRegion.frame = frame;
}

#pragma mark - "UI".

//________________________________________________________________________________________
- (void) fixFlipHintGeometry
{
   CGRect frame = flipHintView.frame;

   if (!currPage.pageNumber) {
      frame.origin.y = self.view.frame.size.height / 2 - frame.size.height / 2;
      frame.origin.x = self.view.frame.size.width - frame.size.width;
   } else {
      frame.origin.y = self.view.frame.size.height / 2 - frame.size.height / 2;
      frame.origin.x = 0.f;
   }
   
   flipHintView.frame = frame;
}

//________________________________________________________________________________________
- (void) showFlipHint
{
   [self.view bringSubviewToFront : flipHintView];
   flipHintView.hidden = NO;
   flipHintView.alpha = 0.3f;
}

//________________________________________________________________________________________
- (void) showRightFlipHint
{
   flipHintView.image = [UIImage imageNamed : @"flip_left.png"];
   if (!flipHintView.superview)
      [self.view addSubview : flipHintView];

   [self fixFlipHintGeometry];
   [self showFlipHint];
}

//________________________________________________________________________________________
- (void) showLeftFlipHint
{
   flipHintView.image = [UIImage imageNamed : @"flip_right.png"];
   if (!flipHintView.superview)
      [self.view addSubview : flipHintView];

   [self fixFlipHintGeometry];

   [self showFlipHint];
}

//________________________________________________________________________________________
- (void) hideFlipHint
{
   flipHintView.hidden = YES;
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

   //No additional animation needed if we have an empty page.
   if (!nPages)
      return;

   [self fixFlipHintGeometry];
   [self layoutPages : YES];
   
   [currPage explodeTiles : toInterfaceOrientation];
   [currPage collectTilesAnimatedForOrientation : toInterfaceOrientation from : CACurrentMediaTime() + duration withDuration : 0.5f];
}

//________________________________________________________________________________________
- (void) didRotateFromInterfaceOrientation : (UIInterfaceOrientation) fromInterfaceOrientation
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
#pragma unused(sender)

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
   
   panGesture.enabled = NO;
   
   if (delayedFlipRefresh) {
      [self refreshAfterFlip];
      delayedFlipRefresh = NO;
   } else {   
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
      //
      //
      [currPage.superview bringSubviewToFront : self.pageControl];
      //
      self.pageControl.activePage = currPage.pageNumber;
      //
      
      
      if (!spinner.hidden)
         [spinner.superview bringSubviewToFront : spinner];
      
      [self loadVisiblePageData];
      
      if (nPages > 1) {
         if (currPage.pageNumber == nPages - 1)
            [self showLeftFlipHint];
         else if (!currPage.pageNumber)
            [self showRightFlipHint];
         else
            [self hideFlipHint];
      }
   }

   panGesture.enabled = YES;
}

//________________________________________________________________________________________
- (void) animationCancelled
{
   flipView.hidden = YES;

   if (delayedFlipRefresh) {
      panGesture.enabled = NO;
      [self refreshAfterFlip];
      delayedFlipRefresh = NO;
      panGesture.enabled = YES;
   } else {
      if (!currPage.superview)
         [self.view addSubview : currPage];

      [currPage.superview bringSubviewToFront : currPage];
      [currPage.superview bringSubviewToFront : self.pageControl];

      if (!spinner.hidden)
         [spinner.superview bringSubviewToFront : spinner];

      [self loadVisiblePageData];
      
      if (nPages > 1) {
         if (currPage.pageNumber == nPages - 1)
            [self showLeftFlipHint];
         else if (!currPage.pageNumber)
            [self showRightFlipHint];
         else
            [self hideFlipHint];
      }
   }
}

//________________________________________________________________________________________
- (BOOL) canStartFlipAnimation : (UIPanGestureRecognizer *) recognizer
{
   assert(recognizer != nil && "canStartFlipAnimation:, parameter 'recognizer' is nil");
   
   if (flipAnimator.flipStartedOnTheLeft)
      return currPage.pageNumber;
   
   return currPage.pageNumber != nPages - 1;
}

//________________________________________________________________________________________
- (BOOL) shouldSkipAnimationFrame : (UIPanGestureRecognizer *) recognizer
{
   assert(recognizer != nil && "shouldSkipAnimationFrame:, parametere 'recognizer' is nil");
   
   const CGPoint currentPoint = [recognizer locationInView : self.view];

   if (flipAnimator.flipStartedOnTheLeft)
      return currentPoint.x < panStartPoint.x;

   return currentPoint.x > panStartPoint.x;
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
         if (flipAnimator.animationLock)
            break;
         
         panStartPoint = [recognizer locationInView : self.view];
         if (CGRectContainsPoint(panRegion.frame, panStartPoint)) {
            flipAnimator.flipStartedOnTheLeft = panStartPoint.x < self.view.frame.size.width / 2;
            
            if ([self canStartFlipAnimation : recognizer] && !flipAnimator.animationState) {
               autoFlipAnimation = NO;
            
               flipView.hidden = NO;
               [flipView.superview bringSubviewToFront : flipView];

               [NSObject cancelPreviousPerformRequestsWithTarget : self];
               flipAnimator.sequenceType = SequenceType::controlled;
               flipAnimator.animationLock = YES;
               
               lastTranslationX = [recognizer translationInView : self.view].x;
            }
         } else
            flipAnimator.flipStartedOnTheLeft = false;
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
                  if (![self shouldSkipAnimationFrame : recognizer] && !autoFlipAnimation) {
                     //Let's test the velocity of a gesture: if the user was too fast, ki... I 'mean,
                     //start slow automatic animation to make him angry.
                     
                     const CGFloat velocityX = [recognizer velocityInView : self.view].x;
                     
                     if (std::abs(velocityX) > 3000.f) {
                        [self startAutoFlipAnimation : recognizer];
                     } else {
                        lastTranslationX = [recognizer translationInView : self.view].x;
                        const CGFloat value = [recognizer translationInView : self.view].x / 2.f;//2 is some arbitrary value here.
                        [flipAnimator setTransformValue : value delegating : NO];
                     }
                  }
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
         if (flipAnimator.animationLock && !autoFlipAnimation) {
            // provide inertia to panning gesture
            flipAnimator.sequenceType = SequenceType::controlled;
            if (![self shouldSkipAnimationFrame : recognizer]) {
               const CGFloat value = sqrtf(fabsf([recognizer velocityInView : self.view].x))/10.0f;
               [flipAnimator endStateWithSpeed : value];
            } else {
               [flipAnimator endStateWithSpeed : 1.f];
            }
         }
      }
      break;
   default:
      break;
   }
}

//________________________________________________________________________________________
- (void) autoAnimationStep
{
   assert(autoFlipAnimation == YES && "autoAnimationStep, called outside of auto animation sequence");
   assert(flipAnimator.animationLock == YES && "autoAnimationStep, no animation lock is active");

   if (autoAnimationStep == nAutoAnimationSteps - 1) {//10 animation steps.
      [flipAnimator endStateWithSpeed : 1.f];
   } else {
      [flipAnimator setTransformValue : (lastTranslationX + autoAnimationStep * autoPanStepX) / 2 delegating : NO];
      ++autoAnimationStep;
      [self performSelector : @selector(autoAnimationStep) withObject : nil afterDelay : 0.03f];
   }
}

//________________________________________________________________________________________
- (void) startAutoFlipAnimation : (UIPanGestureRecognizer *) recognizer
{
   assert(recognizer != nil && "startAutoFlipAnimation:, parameter 'recognizer' is nil");

   autoFlipAnimation = YES;
   autoAnimationStep = 0;

   if (!flipAnimator.flipStartedOnTheLeft) {
      if ([recognizer velocityInView : self.view].x < 0.f) {
         if (std::abs(-M_PI - flipAnimator.currentAngle) < 0.1f)
            [flipAnimator endStateWithSpeed : 1.f];
         else {
            //Flip to the left. The ending angle is -pi.
            autoPanStepX = -50.f;//- M_PI * (lastPanPointX - panStartPoint.x) / flipAnimator.currentAngle;
            [self autoAnimationStep];
         }
      } else {
         //Flip to the right.
         [flipAnimator endStateWithSpeed : 1.f];
      }
   } else {
      if ([recognizer velocityInView : self.view].x > 0.f) {
         if (std::abs(M_PI - flipAnimator.currentAngle) < 0.1f)
            [flipAnimator endStateWithSpeed : 1.f];
         else {
            autoPanStepX = 50.f;
            [self autoAnimationStep];
         }
      } else {
         [flipAnimator endStateWithSpeed : 1.f];
      }
   }
}

//________________________________________________________________________________________
- (void) refreshAfterFlip
{
}

//________________________________________________________________________________________
- (BOOL) canInterruptWithAlert
{
   return YES;
}

@end
