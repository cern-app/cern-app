//
//  FlipView.m
//  flipboard_anim
//
//  Created by Timur Pocheptsov on 4/25/13.
//  Copyright (c) 2013 Timur Pocheptsov. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

#import "AnimationDelegate.h"
#import "AnimationFrame.h"
#import "FlipView.h"

using namespace FlipAnimation;


UIImage * ImageForView(UIView *view)
{
   UIGraphicsBeginImageContextWithOptions(view.bounds.size, view.opaque, 0.0);
   [view.layer renderInContext : UIGraphicsGetCurrentContext()];
   UIImage * img = UIGraphicsGetImageFromCurrentImageContext();
   UIGraphicsEndImageContext();

   return img;
}

@implementation FlipView

@synthesize imageStackArray;
@synthesize textInset;
@synthesize textOffset;
@synthesize fontSize;
@synthesize font;
@synthesize fontAlignment;
@synthesize textTruncationMode;
@synthesize animationType;


//________________________________________________________________________________________
- (id) initWithAnimationType : (FlipAnimation::AnimationType) aType frame : (CGRect) aFrame
{
    self = [super init];
    if (self) {
        // Initialization code
        animationType = aType;
      
        textOffset = CGPointZero;
        textInset = CGPointZero;
        
        self.imageStackArray = [NSMutableArray array];
        
        templateWidth = aFrame.size.width;
        templateHeight = aFrame.size.height;
        self.frame = aFrame;
        
    }

    return self;
}

//________________________________________________________________________________________
- (void) addPage : (UIView *) pageView
{
   templateImage = ImageForView(pageView);
   //
   const CGFloat scale = [[UIScreen mainScreen] scale];
    
    if (true) {
        switch (self.animationType) {
                
            /* For a half-fold (both kAnimationFlipVertical and kAnimationFlipHorizontal),
            there are 10 layers per animation frame (2 transform, 4 content, 4 shadow).
            The transform layers encapsulate the content and shadow so that we don't have
            to apply separate transforms for the front facing and back facing layers */
            case AnimationType::flipVertical: {
                
                CALayer *flipLayer = [CATransformLayer layer];
                flipLayer.frame = CGRectMake(0, 
                                             templateHeight/4, 
                                             templateWidth, 
                                             templateHeight/2);
                flipLayer.anchorPoint = CGPointMake(0.5, 1.0);
                
                CGRect layerRect = CGRectMake(0, 
                                              0, 
                                              templateWidth, 
                                              templateHeight/2);
                
                CALayer *backLayer = [self layerWithFrame:layerRect];
                [flipLayer addSublayer:backLayer];
                
                CALayer *shadowLayer = [self layerWithFrame:layerRect];
                shadowLayer.backgroundColor = [UIColor blackColor].CGColor;
                shadowLayer.opacity = 0.0f;
                [flipLayer addSublayer:shadowLayer];
                
                CALayer *frontLayer = [self layerWithFrame:layerRect];
                frontLayer.transform = CATransform3DMakeRotation(M_PI, 1.0, 0, 0);
                [flipLayer addSublayer:frontLayer];
                
                CALayer *shadowLayer2 = [self layerWithFrame:layerRect];
                shadowLayer2.backgroundColor = [UIColor blackColor].CGColor;
                shadowLayer2.opacity = 0.0f;
                shadowLayer2.transform = CATransform3DMakeRotation(M_PI, 1.0, 0, 0);
                [flipLayer addSublayer:shadowLayer2];
                
                CALayer *flipLayer2 = [CATransformLayer layer];
                flipLayer2.frame = CGRectMake(0, 
                                              templateHeight/4, 
                                              templateWidth, 
                                              templateHeight/2);
                flipLayer2.anchorPoint = CGPointMake(0.5, 0.0);
                
                CALayer *backLayer2 = [self layerWithFrame:layerRect];
                [flipLayer2 addSublayer:backLayer2];
                
                CALayer *shadowLayer3 = [self layerWithFrame:layerRect];
                shadowLayer3.backgroundColor = [UIColor blackColor].CGColor;
                shadowLayer3.opacity = 0.0f;
                [flipLayer2 addSublayer:shadowLayer3];
                
                CALayer *frontLayer2 = [self layerWithFrame:layerRect];
                frontLayer2.transform = CATransform3DMakeRotation(M_PI, 1.0, 0, 0);
                [flipLayer2 addSublayer:frontLayer2];
                
                CALayer *shadowLayer4 = [self layerWithFrame:layerRect];
                shadowLayer4.backgroundColor = [UIColor blackColor].CGColor;
                shadowLayer4.opacity = 0.0f;
                shadowLayer4.transform = CATransform3DMakeRotation(M_PI, 1.0, 0, 0);
                [flipLayer2 addSublayer:shadowLayer4];
                
                CGImageRef imageRef = CGImageCreateWithImageInRect([templateImage CGImage], CGRectMake(0, 0, templateWidth*scale, templateHeight*scale/2));
                
                CGImageRef imageRef2 = CGImageCreateWithImageInRect([templateImage CGImage], CGRectMake(0, templateHeight*scale/2, templateWidth*scale, templateHeight*scale/2));
                
                [backLayer setContents:(__bridge id)imageRef];
                [backLayer2 setContents:(__bridge id)imageRef2];
               
                CFRelease(imageRef);
                CFRelease(imageRef2);
                
                AnimationFrame *newFrame = [[AnimationFrame alloc] init];
                [self.layer addSublayer:newFrame.rootAnimationLayer];
                [newFrame.rootAnimationLayer addSublayer:flipLayer];
                [newFrame.rootAnimationLayer addSublayer:flipLayer2];
                [newFrame addLayers:flipLayer2, flipLayer, nil];
                
                [self.imageStackArray addObject:newFrame];
            }
                break;
            case AnimationType::flipHorizontal: {
                
                CALayer *flipLayer = [CATransformLayer layer];
                flipLayer.frame = CGRectMake(templateWidth/4, 
                                             0, 
                                             templateWidth/2, 
                                             templateHeight);
                flipLayer.anchorPoint = CGPointMake(1.0, 0.5);
                
                CGRect layerRect = CGRectMake(0, 
                                              0, 
                                              templateWidth/2, 
                                              templateHeight);
                
                CALayer *backLayer = [self layerWithFrame:layerRect];
                [flipLayer addSublayer:backLayer];
                
                CALayer *shadowLayer = [self layerWithFrame:layerRect];
                shadowLayer.backgroundColor = [UIColor blackColor].CGColor;
                shadowLayer.opacity = 0.0f;
                [flipLayer addSublayer:shadowLayer];
                
                CALayer *frontLayer = [self layerWithFrame:layerRect];
                frontLayer.transform = CATransform3DMakeRotation(M_PI, 0, 1.0, 0);
                [flipLayer addSublayer:frontLayer];
                
                CALayer *shadowLayer2 = [self layerWithFrame:layerRect];
                shadowLayer2.backgroundColor = [UIColor blackColor].CGColor;
                shadowLayer2.opacity = 0.0f;
                shadowLayer2.transform = CATransform3DMakeRotation(M_PI, 0, 1.0, 0);
                [flipLayer addSublayer:shadowLayer2];
                
                CALayer *flipLayer2 = [CATransformLayer layer];
                flipLayer2.frame = CGRectMake(templateWidth/4, 
                                              0, 
                                              templateWidth/2, 
                                              templateHeight);
                flipLayer2.anchorPoint = CGPointMake(0.0, 0.5);
                
                CALayer *backLayer2 = [self layerWithFrame:layerRect];
                [flipLayer2 addSublayer:backLayer2];
                
                CALayer *shadowLayer3 = [self layerWithFrame:layerRect];
                shadowLayer3.backgroundColor = [UIColor blackColor].CGColor;
                shadowLayer3.opacity = 0.0f;
                [flipLayer2 addSublayer:shadowLayer3];
                
                CALayer *frontLayer2 = [self layerWithFrame:layerRect];
                frontLayer2.transform = CATransform3DMakeRotation(M_PI, 0, 1.0, 0);
                [flipLayer2 addSublayer:frontLayer2];
                
                CALayer *shadowLayer4 = [self layerWithFrame:layerRect];
                shadowLayer4.backgroundColor = [UIColor blackColor].CGColor;
                shadowLayer4.opacity = 0.0f;
                shadowLayer4.transform = CATransform3DMakeRotation(M_PI, 0, 1.0, 0);
                [flipLayer2 addSublayer:shadowLayer4];
                
                CGImageRef imageRef = CGImageCreateWithImageInRect([templateImage CGImage], CGRectMake(templateWidth*scale/2, 0, templateWidth*scale/2, templateHeight*scale));
                
                CGImageRef imageRef2 = CGImageCreateWithImageInRect([templateImage CGImage], CGRectMake(0, 0, templateWidth*scale/2, templateHeight*scale));
                
                [backLayer setContents:(__bridge id)imageRef2];
                [backLayer2 setContents:(__bridge id)imageRef];
               
                CFRelease(imageRef);
                CFRelease(imageRef2);
                
                AnimationFrame *newFrame = [[AnimationFrame alloc] init];
                [self.layer addSublayer:newFrame.rootAnimationLayer];
                [newFrame.rootAnimationLayer addSublayer:flipLayer];
                [newFrame.rootAnimationLayer addSublayer:flipLayer2];
                [newFrame addLayers:flipLayer2, flipLayer, nil];
                
                [self.imageStackArray addObject:newFrame];
            }
                break;
            default:
                break;
        }
    }
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

   [self addPage : pageView];

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
  
   [self addPage : pageView];
   
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
- (CALayer *) layerWithFrame : (CGRect)aFrame
{
    CALayer *layer = [CALayer layer];
    layer.frame = aFrame;
    layer.masksToBounds = YES;
    layer.doubleSided = NO;
    layer.contentsGravity = kCAGravityResizeAspect;
    
    return layer;
}

//________________________________________________________________________________________
- (void) rearrangeLayers : (FlipAnimation::DirectionType) aDirectionType  : (int) step
{
   //Pop the last set of images and push back onto the stack,
   //to prepare for the next animation sequence.

   if ([self.imageStackArray count] > 1) {
       AnimationFrame *currentFrame = [self.imageStackArray lastObject];
       AnimationFrame *previousFrame = [self.imageStackArray objectAtIndex:0];
       AnimationFrame *previousPreviousFrame = [self.imageStackArray objectAtIndex:1];
       AnimationFrame *nextFrame = [self.imageStackArray objectAtIndex:[self.imageStackArray count]-2];
       
       if (aDirectionType == DirectionType::forward) {
           
           if (step == 3) {
               [currentFrame.rootAnimationLayer removeFromSuperlayer];
               [self.layer insertSublayer : currentFrame.rootAnimationLayer below:previousFrame.rootAnimationLayer];
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
