#import <QuartzCore/QuartzCore.h>

#import "AnimationDelegate.h"
#import "AnimationFrame.h"
#import "FlipView.h"

//This code is based on Dillion Tan's GenericAnimationView + FlipView.

using namespace FlipAnimation;

namespace {

//________________________________________________________________________________________
UIImage * ImageForView(UIView *view)
{
   assert(view != nil && "ImageForView, parameter 'view' is nil");

   UIGraphicsBeginImageContextWithOptions(view.bounds.size, view.opaque, 0.0);
   [view.layer renderInContext : UIGraphicsGetCurrentContext()];
   UIImage * img = UIGraphicsGetImageFromCurrentImageContext();
   UIGraphicsEndImageContext();

   return img;
}

//________________________________________________________________________________________
CALayer *LayerForFrame(const CGRect &frame)
{
   assert(frame.size.width > 0.f && frame.size.height > 0.f &&
          "LayerForFrame, parameter 'frame' is not a valid rectangle");

   CALayer *layer = [CALayer layer];
   layer.frame = frame;
   layer.masksToBounds = YES;
   layer.doubleSided = NO;
   layer.contentsGravity = kCAGravityResizeAspect;

   return layer;
}

}

@implementation FlipView {
   // size of the view determines size of all Animation Frames
   CGFloat templateWidth;
   CGFloat templateHeight;
}

@synthesize imageStackArray;
@synthesize animationType;

//________________________________________________________________________________________
- (id) initWithAnimationType : (FlipAnimation::AnimationType) aType frame : (CGRect) aFrame
{
   self = [super init];
   if (self) {
      // Initialization code
      animationType = aType;
      
      self.imageStackArray = [NSMutableArray array];
        
      templateWidth = aFrame.size.width;
      templateHeight = aFrame.size.height;
      self.frame = aFrame;
      
      self.backgroundColor = [UIColor whiteColor];
   }

   return self;
}

//________________________________________________________________________________________
-(void) setFrameGeometry : (CGSize) frameSize
{
   assert(frameSize.width > 0.f && frameSize.height > 0.f &&
          "setFrameGeometry:, parameter 'frameSize' is not a valid frame size");
   assert(self.imageStackArray.count == 0 &&
          "setFrameGeometry:, can not set frame geometry with non-empty frame stack");
   
   templateHeight = frameSize.height;
   templateWidth = frameSize.width;
}

//________________________________________________________________________________________
- (void) addFrame : (UIView *) pageView
{
   //Taken from flip view by Dillon Tan.

   UIImage * const templateImage = ImageForView(pageView);
   assert(templateImage != nil && "addPage:, can not render a page view into an image");
   const CGFloat scale = [[UIScreen mainScreen] scale];
   
   if (true) {
      switch (self.animationType) {
      /* For a half-fold (both kAnimationFlipVertical and kAnimationFlipHorizontal),
      there are 10 layers per animation frame (2 transform, 4 content, 4 shadow).
      The transform layers encapsulate the content and shadow so that we don't have
      to apply separate transforms for the front facing and back facing layers */
      case AnimationType::flipVertical:
         {
            CALayer * const flipLayer = [CATransformLayer layer];
            flipLayer.frame = CGRectMake(0, templateHeight/4, templateWidth, templateHeight/2);
            flipLayer.anchorPoint = CGPointMake(0.5, 1.0);
            const CGRect layerRect = CGRectMake(0, 0, templateWidth, templateHeight/2);

            CALayer * const backLayer = LayerForFrame(layerRect);
            [flipLayer addSublayer:backLayer];

            CALayer * const shadowLayer = LayerForFrame(layerRect);
            shadowLayer.backgroundColor = [UIColor blackColor].CGColor;
            shadowLayer.opacity = 0.0f;
            [flipLayer addSublayer:shadowLayer];

            CALayer * const frontLayer = LayerForFrame(layerRect);
            frontLayer.transform = CATransform3DMakeRotation(M_PI, 1.0, 0, 0);
            [flipLayer addSublayer:frontLayer];

            CALayer * const shadowLayer2 = LayerForFrame(layerRect);
            shadowLayer2.backgroundColor = [UIColor blackColor].CGColor;
            shadowLayer2.opacity = 0.0f;
            shadowLayer2.transform = CATransform3DMakeRotation(M_PI, 1.0, 0, 0);
            [flipLayer addSublayer:shadowLayer2];

            CALayer * const flipLayer2 = [CATransformLayer layer];
            flipLayer2.frame = CGRectMake(0, templateHeight/4, templateWidth, templateHeight/2);
            flipLayer2.anchorPoint = CGPointMake(0.5, 0.0);

            CALayer * const backLayer2 = LayerForFrame(layerRect);
            [flipLayer2 addSublayer:backLayer2];

            CALayer * const shadowLayer3 = LayerForFrame(layerRect);
            shadowLayer3.backgroundColor = [UIColor blackColor].CGColor;
            shadowLayer3.opacity = 0.0f;
            [flipLayer2 addSublayer:shadowLayer3];

            CALayer * const frontLayer2 = LayerForFrame(layerRect);
            frontLayer2.transform = CATransform3DMakeRotation(M_PI, 1.0, 0, 0);
            [flipLayer2 addSublayer:frontLayer2];

            CALayer * const shadowLayer4 = LayerForFrame(layerRect);
            shadowLayer4.backgroundColor = [UIColor blackColor].CGColor;
            shadowLayer4.opacity = 0.0f;
            shadowLayer4.transform = CATransform3DMakeRotation(M_PI, 1.0, 0, 0);
            [flipLayer2 addSublayer:shadowLayer4];

            CGImageRef imageRef = CGImageCreateWithImageInRect([templateImage CGImage], CGRectMake(0, 0, templateWidth*scale, templateHeight*scale/2));
            CGImageRef imageRef2 = CGImageCreateWithImageInRect([templateImage CGImage], CGRectMake(0, templateHeight*scale/2, templateWidth*scale, templateHeight*scale/2));

            [backLayer setContents : (__bridge id)imageRef];
            [backLayer2 setContents : (__bridge id)imageRef2];

            CFRelease(imageRef);
            CFRelease(imageRef2);

            AnimationFrame * const newFrame = [[AnimationFrame alloc] init];
            [self.layer addSublayer:newFrame.rootAnimationLayer];
            [newFrame.rootAnimationLayer addSublayer:flipLayer];
            [newFrame.rootAnimationLayer addSublayer:flipLayer2];
            [newFrame addLayers:flipLayer2, flipLayer, nil];

            [self.imageStackArray addObject:newFrame];
         }
         break;
      case AnimationType::flipHorizontal:
         {

            CALayer *flipLayer = [CATransformLayer layer];
            flipLayer.frame = CGRectMake(templateWidth/4, 0, templateWidth/2, templateHeight);
            flipLayer.anchorPoint = CGPointMake(1.0, 0.5);

            const CGRect layerRect = CGRectMake(0, 0, templateWidth/2, templateHeight);

            CALayer * const backLayer = LayerForFrame(layerRect);
            [flipLayer addSublayer:backLayer];

            CALayer * const shadowLayer = LayerForFrame(layerRect);
            shadowLayer.backgroundColor = [UIColor blackColor].CGColor;
            shadowLayer.opacity = 0.0f;
            [flipLayer addSublayer:shadowLayer];

            CALayer * const frontLayer = LayerForFrame(layerRect);
            frontLayer.transform = CATransform3DMakeRotation(M_PI, 0, 1.0, 0);
            [flipLayer addSublayer:frontLayer];

            CALayer * const shadowLayer2 = LayerForFrame(layerRect);
            shadowLayer2.backgroundColor = [UIColor blackColor].CGColor;
            shadowLayer2.opacity = 0.0f;
            shadowLayer2.transform = CATransform3DMakeRotation(M_PI, 0, 1.0, 0);
            [flipLayer addSublayer:shadowLayer2];

            CALayer * const flipLayer2 = [CATransformLayer layer];
            flipLayer2.frame = CGRectMake(templateWidth/4, 0, templateWidth/2, templateHeight);
            flipLayer2.anchorPoint = CGPointMake(0.0, 0.5);

            CALayer * const backLayer2 = LayerForFrame(layerRect);
            [flipLayer2 addSublayer:backLayer2];

            CALayer * const shadowLayer3 = LayerForFrame(layerRect);
            shadowLayer3.backgroundColor = [UIColor blackColor].CGColor;
            shadowLayer3.opacity = 0.0f;
            [flipLayer2 addSublayer:shadowLayer3];

            CALayer * const frontLayer2 = LayerForFrame(layerRect);
            frontLayer2.transform = CATransform3DMakeRotation(M_PI, 0, 1.0, 0);
            [flipLayer2 addSublayer:frontLayer2];

            CALayer * const shadowLayer4 = LayerForFrame(layerRect);
            shadowLayer4.backgroundColor = [UIColor blackColor].CGColor;
            shadowLayer4.opacity = 0.0f;
            shadowLayer4.transform = CATransform3DMakeRotation(M_PI, 0, 1.0, 0);
            [flipLayer2 addSublayer:shadowLayer4];

            CGImageRef imageRef = CGImageCreateWithImageInRect([templateImage CGImage], CGRectMake(templateWidth*scale/2, 0, templateWidth*scale/2, templateHeight*scale));
            CGImageRef imageRef2 = CGImageCreateWithImageInRect([templateImage CGImage], CGRectMake(0, 0, templateWidth*scale/2, templateHeight*scale));

            [backLayer setContents : (__bridge id)imageRef2];
            [backLayer2 setContents : (__bridge id)imageRef];

            CFRelease(imageRef);
            CFRelease(imageRef2);

            AnimationFrame * const newFrame = [[AnimationFrame alloc] init];
            [self.layer addSublayer:newFrame.rootAnimationLayer];
            [newFrame.rootAnimationLayer addSublayer:flipLayer];
            [newFrame.rootAnimationLayer addSublayer:flipLayer2];
            [newFrame addLayers:flipLayer2, flipLayer, nil];

            [self.imageStackArray addObject:newFrame];
         }
         break;
      default:
         assert(0 && "addPage:, unknown animation type");
         break;
      }
   }
}

//________________________________________________________________________________________
- (void) removeAllFrames
{
   for (AnimationFrame *frame in self.imageStackArray)
      [frame.rootAnimationLayer removeFromSuperlayer];
   
   [self.imageStackArray removeAllObjects];
}

//________________________________________________________________________________________
- (void) shiftBackwardWithNewPage : (UIView *) pageView
{
   assert(pageView != nil && "shiftBackwardWithNewPage:, parameter 'pageView' is nil");
   assert(self.imageStackArray.count == 3 && "shiftBackwardWithNewPage:, number of frames != 3");
   
   //Now, do a trick.
   //Frame order was affected by rearrangeLayers::, before animation it was
   //'prev' 'next' 'curr', now it's 'next' 'curr' 'prev' (the meaning of 'next' etc. is
   //the same as before animation).

   [self addFrame : pageView];

   //Remove one old frame and resort frame stack.
   AnimationFrame * const oldPrev = (AnimationFrame *)self.imageStackArray[2];
   //'oldNext' will be lost after this operation.
   AnimationFrame * const oldCurr = (AnimationFrame *)self.imageStackArray[1];
   AnimationFrame * const newFrame = (AnimationFrame *)self.imageStackArray[3];
   
   for (AnimationFrame *frame in self.imageStackArray)
      [frame.rootAnimationLayer removeFromSuperlayer];
   
   [self.imageStackArray removeAllObjects];
   
   [self.imageStackArray addObject : newFrame];
   [self.layer addSublayer : newFrame.rootAnimationLayer];
   [self.imageStackArray addObject : oldCurr];
   [self.layer addSublayer : oldCurr.rootAnimationLayer];
   [self.imageStackArray addObject : oldPrev];
   [self.layer addSublayer : oldPrev.rootAnimationLayer];  
}

//________________________________________________________________________________________
- (void) shiftForwardWithNewPage : (UIView *) pageView
{
   assert(pageView != nil && "shiftForwareWithNewPage:, parameter 'pageView' is nil");
   assert(self.imageStackArray.count == 3 && "shiftForwardWithNewPage:, number of frames != 3");
  
   [self addFrame : pageView];
   
   AnimationFrame * const oldCurr = (AnimationFrame *)self.imageStackArray[0];
   AnimationFrame * const oldNext = (AnimationFrame *)self.imageStackArray[2];
   AnimationFrame * const newFrame = (AnimationFrame *)self.imageStackArray[3];

   //Remove one frame and resort the remaining.
   for (AnimationFrame *frame in self.imageStackArray)
      [frame.rootAnimationLayer removeFromSuperlayer];
   
   [self.imageStackArray removeAllObjects];
   
   [self.imageStackArray addObject : oldCurr];
   [self.layer addSublayer : oldCurr.rootAnimationLayer];
   [self.imageStackArray addObject : newFrame];
   [self.layer addSublayer : newFrame.rootAnimationLayer];
   [self.imageStackArray addObject : oldNext];
   [self.layer addSublayer : oldNext.rootAnimationLayer];
}

//________________________________________________________________________________________
- (void) replaceCurrentFrame : (UIView *) pageView
{
   assert(pageView != nil && "replaceCurrentFrame:, paramter 'pageView' is nil");
   
   AnimationFrame * const oldCurr = (AnimationFrame *)[self.imageStackArray lastObject];
   [oldCurr.rootAnimationLayer removeFromSuperlayer];
   
   [self.imageStackArray removeLastObject];
   [self addFrame : pageView];
}

//________________________________________________________________________________________
- (void) rearrangeLayers : (FlipAnimation::DirectionType) aDirectionType  : (NSUInteger) step
{
   //Pop the last set of images and push back onto the stack,
   //to prepare for the next animation sequence.

   if ([self.imageStackArray count] > 1) {
      AnimationFrame * const currentFrame = [self.imageStackArray lastObject];
      AnimationFrame * const previousFrame = [self.imageStackArray objectAtIndex:0];
      AnimationFrame * const previousPreviousFrame = [self.imageStackArray objectAtIndex:1];
      AnimationFrame * const nextFrame = [self.imageStackArray objectAtIndex:[self.imageStackArray count]-2];
      
      if (aDirectionType == DirectionType::forward) {
         if (step == 3) {
            [currentFrame.rootAnimationLayer removeFromSuperlayer];
            [self.layer insertSublayer:currentFrame.rootAnimationLayer below:previousFrame.rootAnimationLayer];
            [self.imageStackArray removeLastObject];
            [self.imageStackArray insertObject:currentFrame atIndex:0];
         }
      } else if (aDirectionType == DirectionType::backward) {
         if (step == 1) {
            if ([self.imageStackArray count] > 2) {
               [previousFrame.rootAnimationLayer removeFromSuperlayer];
               [self.layer insertSublayer:previousFrame.rootAnimationLayer above:nextFrame.rootAnimationLayer];
            }

         } else if (step == 2) {
            if ([self.imageStackArray count] > 2) {
               [previousFrame.rootAnimationLayer removeFromSuperlayer];
               [self.layer insertSublayer:previousFrame.rootAnimationLayer below:previousPreviousFrame.rootAnimationLayer];
            }
         } else if (step == 3) {
            [previousFrame.rootAnimationLayer removeFromSuperlayer];
            [self.layer insertSublayer:previousFrame.rootAnimationLayer above:currentFrame.rootAnimationLayer];
            [self.imageStackArray removeObjectAtIndex:0];
            [self.imageStackArray addObject:previousFrame];
         }
      }
   }
}

@end
