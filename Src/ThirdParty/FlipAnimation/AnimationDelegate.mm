
/*
 
 File: AnimationDelegate.m
 Abstract: Animation Delegate is the helper to handle callbacks
 from transform operations. The animation 
 delegate should have knowledge of how and what kind of transform
 should be applied to current animation frame, based on the type
 of animation and various user settings.
 
 
 Copyright (c) 2011 Dillion Tan
 
 Permission is hereby granted, free of charge, to any person
 obtaining a copy of this software and associated documentation
 files (the "Software"), to deal in the Software without
 restriction, including without limitation the rights to use,
 copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the
 Software is furnished to do so, subject to the following
 conditions:
 
 The above copyright notice and this permission notice shall be
 included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 OTHER DEALINGS IN THE SOFTWARE.
 
 */

//Modified for CERN.app by Timur Pocheptsov.

#import <algorithm>
#import <cassert>
#import <cmath>

#import <QuartzCore/QuartzCore.h>

#import "AnimationDelegate.h"
#import "FlipAnimatedView.h"
#import "AnimationFrame.h"

using FlipAnimation::SequenceType;
using FlipAnimation::AnimationType;
using FlipAnimation::DirectionType;

@implementation AnimationDelegate {
   CGImageRef transitionImageBackup;
   CGFloat currentDuration;
   FlipAnimation::DirectionType currentDirection;
   CGFloat value;
   CGFloat newValue;
   CGFloat oldOpacityValue;
}

@synthesize transformView;
@synthesize controller;
@synthesize nextDuration;
@synthesize sequenceType;
@synthesize animationState;
@synthesize animationLock;
@synthesize shadow;
@synthesize sensitivity;
@synthesize gravity;
@synthesize perspectiveDepth;

//________________________________________________________________________________________
- (id) initWithSequenceType : (FlipAnimation::SequenceType) aType
              directionType : (FlipAnimation::DirectionType) aDirection
{
   if ((self = [super init])) {
      transformView = nil;
      controller = nil;

      sequenceType = aType;
      currentDirection = aDirection;

      // default values
      nextDuration = 0.6f;
      sensitivity = 40;
      gravity = 2;
      perspectiveDepth = 500;
      shadow = YES;
   }

   return self;
}

//________________________________________________________________________________________
- (BOOL) startAnimation : (FlipAnimation::DirectionType) aDirection
{
   if (animationState == 0) {

      [NSObject cancelPreviousPerformRequestsWithTarget:self];

      if (aDirection != DirectionType::none)
         currentDirection = aDirection;

      switch (currentDirection) {
      case DirectionType::forward:
         [self setTransformValue : 10.0f delegating : YES];
         return YES;
      case DirectionType::backward:
         [self setTransformValue : -10.0f delegating : YES];
         return YES;
      default:
         assert(0 && "startAnimation:, unknown direction");
         break;
      }
   }
   
   return NO;
}

//________________________________________________________________________________________
- (void) animationDidStop : (CABasicAnimation *) theAnimation finished : (BOOL) finished
{
   if (finished) {
      switch (animationState) {
      case 0:
         break;
      case 1:
         switch (transformView.animationType) {
         case AnimationType::flipVertical:
         case AnimationType::flipHorizontal:
            [self animationCallback];
            break;
         default:
            break;
         }
         
         break;
      default:
         break;
      }
   }
}

//________________________________________________________________________________________
- (void) animationCallback 
{
   [self resetTransformValues];
}

//________________________________________________________________________________________
- (void) endStateWithSpeed : (CGFloat) aVelocity
{
   if (value == 0.0f) {
      [self resetTransformValues];
   } else if (value == 10.0f) {
      [self resetTransformValues];
   } else {
        
      AnimationFrame *currentFrame = [transformView.imageStackArray lastObject];
      CALayer *targetLayer = nil;
        
      int aX = 0, aY = 0, aZ = 0;
      int rotationModifier = 0;
        
      switch (transformView.animationType) {
      case AnimationType::flipVertical:
         aX = 1;
         aY = 0;
         aZ = 0;
         rotationModifier = -1;

         break;
      case AnimationType::flipHorizontal:
         aX = 0;
         aY = 1;
         aZ = 0;
         rotationModifier = 1;
         
         break;
      default :
         assert(0 && "endStateWithSpeed:, unknown animation type");
         break;
      }
      
      CGFloat rotationAfterDirection = 0.f;
        
      if (currentDirection == DirectionType::forward) {
         rotationAfterDirection = M_PI * rotationModifier;
         targetLayer = [currentFrame.animationImages lastObject];
      } else if (currentDirection == DirectionType::backward) {
         rotationAfterDirection = -M_PI * rotationModifier;
         targetLayer = [currentFrame.animationImages objectAtIndex:0];
      } else {
         assert(0 && "endStateWithSpeed:, unknown animation direction");
      }
      
      CALayer *targetShadowLayer = nil;
        
      CATransform3D aTransform = CATransform3DIdentity;
      aTransform.m34 = 1.f / -perspectiveDepth;
      [targetLayer setValue : [NSValue valueWithCATransform3D : CATransform3DRotate(aTransform, rotationAfterDirection / 10.f * value, aX, aY, aZ)] forKeyPath : @"transform"];

      for (CALayer *layer in targetLayer.sublayers)
         [layer removeAllAnimations];

      [targetLayer removeAllAnimations];
        
      if (gravity > 0) {
            
         animationState = 1;

         if (value + aVelocity <= 5.f) {
            targetShadowLayer = [targetLayer.sublayers objectAtIndex : 1];
            [self setTransformProgress : rotationAfterDirection / 10.f * value
                                       : 0.0f
                                       : 1.0f/(gravity+aVelocity)
                                       : aX : aY : aZ
                                       : YES : NO
                                       : kCAFillModeForwards
                                       : targetLayer];

            if (shadow) {
               [self setOpacityProgress : oldOpacityValue
                                        : 0.f
                                        : 0.f
                                        : currentDuration
                                        : kCAFillModeForwards
                                        : targetShadowLayer];
            }
            
            value = 0.f;
         } else {
            targetShadowLayer = [targetLayer.sublayers objectAtIndex : 3];

            [self setTransformProgress : rotationAfterDirection / 10.f * value
                                       : rotationAfterDirection
                                       : 1.f / (gravity + aVelocity)
                                       : aX : aY : aZ
                                       : YES : NO
                                       : kCAFillModeForwards
                                       : targetLayer];

            if (shadow) {
               [self setOpacityProgress : oldOpacityValue
                                        : 0.f
                                        : 0.f
                                        : currentDuration
                                        : kCAFillModeForwards
                                        : targetShadowLayer];
            }
            value = 10.f;
         }
      }
   }
}

//________________________________________________________________________________________
- (void) resetTransformValues
{
   AnimationFrame *currentFrame = [transformView.imageStackArray lastObject];
    
   CALayer *targetLayer = nil;
    
   if (currentDirection == DirectionType::forward) {
      targetLayer = [currentFrame.animationImages lastObject];
   } else if (currentDirection == DirectionType::backward) {
      targetLayer = [currentFrame.animationImages objectAtIndex:0];
   } else {
      assert(0 && "resetTransformValue, unknown animation direction");
   }
   
   CALayer * const targetShadowLayer = [targetLayer.sublayers objectAtIndex : 1];
   CALayer * const targetShadowLayer2 = [targetLayer.sublayers objectAtIndex : 3];
    
   [CATransaction begin];
   [CATransaction setDisableActions : YES];
    
   [targetLayer setValue : [NSValue valueWithCATransform3D : CATransform3DIdentity] forKeyPath : @"transform"];
   targetShadowLayer.opacity = 0.f;
   targetShadowLayer2.opacity = 0.f;
   
   for (CALayer *layer in targetLayer.sublayers)
      [layer removeAllAnimations];

   [targetLayer removeAllAnimations];
    
   targetLayer.zPosition = 0;
    
   CATransform3D aTransform = CATransform3DIdentity;
   targetLayer.sublayerTransform = aTransform;
    
   if (value == 10.0f) {
      [transformView rearrangeLayers : currentDirection : 3];
   } else {
      [transformView rearrangeLayers : currentDirection : 2];
   }
    
   [CATransaction commit];
    
   if (controller && [controller respondsToSelector : @selector(animationDidFinish:)]) {
      if (currentDirection == DirectionType::forward && value == 10.f) {
         [controller animationDidFinish : 1];
      } else if (currentDirection == DirectionType::backward && value == 10.f) {
         [controller animationDidFinish : -1];
      }
   }
    
   animationState = 0;
   animationLock = NO;
   transitionImageBackup = nil;
   value = 0.f;
   oldOpacityValue = 0.0f;
}

// set the progress of the animation
//________________________________________________________________________________________
- (void) setTransformValue : (CGFloat) aValue delegating : (BOOL) bValue
{
   currentDuration = nextDuration;
    
   const NSUInteger frameCount = [transformView.imageStackArray count];
   
   AnimationFrame * const currentFrame = [transformView.imageStackArray lastObject];

   AnimationFrame* nextFrame = [transformView.imageStackArray objectAtIndex:frameCount-2];
   AnimationFrame* previousFrame = [transformView.imageStackArray objectAtIndex:0];

   int aX = 0, aY = 0, aZ = 0;
   int rotationModifier = 0;
   
   switch (transformView.animationType) {
   case AnimationType::flipVertical:
      aX = 1;
      aY = 0;
      aZ = 0;
      rotationModifier = -1;
      break;
   case AnimationType::flipHorizontal:
      aX = 0;
      aY = 1;
      aZ = 0;
      rotationModifier = 1;
      break;
   default:
      assert(0 && "setTransformValue:delegating:, unknown animation type");
      break;
   }
    

   CALayer *targetLayer = nil;
   if (transitionImageBackup == nil) {
      if (aValue - value >= 0.0f) {
         currentDirection = DirectionType::forward;
         switch (transformView.animationType) {
         case AnimationType::flipVertical:
         case AnimationType::flipHorizontal:
            targetLayer = [currentFrame.animationImages lastObject];
            targetLayer.zPosition = 100;
            break;
         default:
            assert(0 && "setTransformValue:delegating:, unknown animation type");
            break;
         }
         animationState++;
      } else if (aValue - value < 0.0f) {
         currentDirection = DirectionType::backward;
         [transformView rearrangeLayers:currentDirection :1];
         switch (transformView.animationType) {
         case AnimationType::flipVertical:
         case AnimationType::flipHorizontal:
            targetLayer = [currentFrame.animationImages objectAtIndex:0];
            targetLayer.zPosition = 100;
            break;
         default:
            assert(0 && "setTransformValue:delegating:, unknown animation type");
            break;
         }
         animationState++;
      }
   }

   float rotationAfterDirection = 0.f;
   if (currentDirection == DirectionType::forward) {
      rotationAfterDirection = M_PI * rotationModifier;
      targetLayer = [currentFrame.animationImages lastObject];
   } else if (currentDirection == DirectionType::backward) {
      rotationAfterDirection = -M_PI * rotationModifier;
      targetLayer = [currentFrame.animationImages objectAtIndex:0];
   } else {
      assert(0 && "setTransformValue:delegating:, unknown direction");
   }
   
   CGFloat adjustedValue = 0.f;
   CGFloat opacityValue = 0.f;
   if (sequenceType == SequenceType::controlled) {
      adjustedValue = fabs(aValue * (sensitivity / 1000.f));
   } else {
      adjustedValue = fabs(aValue);
   }
   
   adjustedValue = std::max(0.f, adjustedValue);
   adjustedValue = std::min(10.f, adjustedValue);
   
   if (adjustedValue <= 5.f) {
      opacityValue = adjustedValue / 10.f;
   } else if (adjustedValue > 5.f) {
      opacityValue = (10.f - adjustedValue)/10.f;
   }
   
   CALayer *targetFrontLayer = nil, *targetBackLayer = nil;   
   switch (transformView.animationType) {
   case AnimationType::flipVertical:
      {
         switch (currentDirection) {
         case DirectionType::forward:
            {
               targetFrontLayer = [targetLayer.sublayers objectAtIndex:2];
               CALayer *nextLayer = [nextFrame.animationImages objectAtIndex:0];
               targetBackLayer = [nextLayer.sublayers objectAtIndex:0];
            }
            break;
         case DirectionType::backward:
            {
               targetFrontLayer = [targetLayer.sublayers objectAtIndex:2];
               CALayer *previousLayer = [previousFrame.animationImages objectAtIndex:1];
               targetBackLayer = [previousLayer.sublayers objectAtIndex:0];
            }
            break;
         default:
            assert(0 && "setTransformValue:delegating:, unknown direction");
            break;
         }
         
      }

      break;
   case AnimationType::flipHorizontal:
      {
         switch (currentDirection) {
         case DirectionType::forward:
            {
               targetFrontLayer = [targetLayer.sublayers objectAtIndex:2];
               CALayer *nextLayer = [nextFrame.animationImages objectAtIndex:0];
               targetBackLayer = [nextLayer.sublayers objectAtIndex:0];
            }
         break;
         case DirectionType::backward:
            {
               targetFrontLayer = [targetLayer.sublayers objectAtIndex:2];
               CALayer *previousLayer = [previousFrame.animationImages objectAtIndex:1];
               targetBackLayer = [previousLayer.sublayers objectAtIndex:0];
            }
         break;
         default:
            assert(0 && "setTransformValue:delegating:, unknown direction");
            break;
         }
      }
      break;
   default:
      assert(0 && "setTransformValue:delegating:, unknown animation type");
      break;
   }
   
   CALayer *targetShadowLayer = nil, *targetShadowLayer2 = nil;
   if (adjustedValue == 10.0f && value == 0.f) {
      targetShadowLayer = [targetLayer.sublayers objectAtIndex:1];
      targetShadowLayer2 = [targetLayer.sublayers objectAtIndex:3];
   } else if (adjustedValue <= 5.0f) {
      targetShadowLayer = [targetLayer.sublayers objectAtIndex:1];
   } else {
      targetShadowLayer = [targetLayer.sublayers objectAtIndex:3];
   }
   
   [CATransaction begin];
   [CATransaction setDisableActions:YES];

   CATransform3D aTransform = CATransform3DIdentity;
   aTransform.m34 = 1.f / -perspectiveDepth;
   [targetLayer setValue : [NSValue valueWithCATransform3D : CATransform3DRotate(aTransform, rotationAfterDirection/10.0 * value, aX, aY, aZ)] forKeyPath : @"transform"];
   targetShadowLayer.opacity = oldOpacityValue;
   
   if (targetShadowLayer2)
      targetShadowLayer2.opacity = oldOpacityValue;
   
   for (CALayer *layer in targetLayer.sublayers)
      [layer removeAllAnimations];

   [targetLayer removeAllAnimations];
    
   [CATransaction commit];
    
    if (adjustedValue != value) {
      CATransform3D aTransform = CATransform3DIdentity;
      aTransform.m34 = 1.0 / -perspectiveDepth;
      targetLayer.sublayerTransform = aTransform;
       
      if (!transitionImageBackup) { //transition has begun, copy the layer content for the reverse layer
         CGImageRef tempImageRef = (__bridge CGImageRef)targetBackLayer.contents;
         transitionImageBackup = (__bridge CGImageRef)targetFrontLayer.contents;
         targetFrontLayer.contents = (__bridge id)tempImageRef;
      } 
        
      [self setTransformProgress : (rotationAfterDirection / 10.f * value)
                                 : (rotationAfterDirection / 10.f * adjustedValue)
                                 : currentDuration
                                 : aX : aY : aZ
                                 : bValue
                                 : NO
                                 : kCAFillModeForwards
                                 : targetLayer];
        
      if (shadow) {
         if (oldOpacityValue == 0.f && oldOpacityValue == opacityValue) {
            [self setOpacityProgress : 0.f : 0.5f : 0.0f : currentDuration / 2
                 : kCAFillModeForwards : targetShadowLayer];
            [self setOpacityProgress : 0.5f : 0.f : currentDuration / 2
                  : currentDuration / 2 : kCAFillModeBackwards : targetShadowLayer2];
         } else {
            [self setOpacityProgress : oldOpacityValue : opacityValue
                                     : 0.0f : currentDuration : kCAFillModeForwards
                                     : targetShadowLayer];
         }
      }
       
      value = adjustedValue;
      oldOpacityValue = opacityValue;
   }
}

//________________________________________________________________________________________
- (void)setTransformProgress:(CGFloat)startTransformValue
                            :(CGFloat)endTransformValue
                            :(CGFloat)duration
                            :(int)aX 
                            :(int)aY 
                            :(int)aZ
                            :(BOOL)setDelegate
                            :(BOOL)removedOnCompletion
                            :(NSString *)fillMode
                            :(CALayer *)targetLayer
{
   CATransform3D aTransform = CATransform3DIdentity;
   aTransform.m34 = 1.0 / -perspectiveDepth;

   CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"transform"];
   anim.duration = duration;
   anim.fromValue= [NSValue valueWithCATransform3D:CATransform3DRotate(aTransform, startTransformValue, aX, aY, aZ)];
   anim.toValue=[NSValue valueWithCATransform3D:CATransform3DRotate(aTransform, endTransformValue, aX, aY, aZ)];
   if (setDelegate) {
      anim.delegate = self;
   }
   anim.removedOnCompletion = removedOnCompletion;
   [anim setFillMode:fillMode];

   [targetLayer addAnimation:anim forKey:@"transformAnimation"];
}

//________________________________________________________________________________________
- (void)setOpacityProgress:(float)startOpacityValue
                          :(float)endOpacityValue
                          :(float)beginTime
                          :(float)duration
                          :(NSString *)fillMode
                          :(CALayer *)targetLayer
{
   CFTimeInterval localMediaTime = [targetLayer convertTime:CACurrentMediaTime() fromLayer:nil];
   CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"opacity"];
   anim.duration = duration;
   anim.fromValue= [NSNumber numberWithFloat:startOpacityValue];
   anim.toValue= [NSNumber numberWithFloat:endOpacityValue];
   anim.beginTime = localMediaTime+beginTime;
   anim.removedOnCompletion = NO;
   [anim setFillMode:fillMode];

   [targetLayer addAnimation:anim forKey:@"opacityAnimation"];
}

@end
