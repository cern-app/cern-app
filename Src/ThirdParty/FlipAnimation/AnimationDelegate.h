
/*
 
 File: AnimationDelegate.h
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

#import <Foundation/Foundation.h>

@class FlipView;

namespace FlipAnimation {

enum class SequenceType : char {
   triggered,    // animation executes once per input, input during execution is ignored
   controlled,   // animation updates to a new state whenever input is received
};

enum class AnimationType : char {
   flipVertical,
   flipHorizontal
};

enum class DirectionType : char {
   none,
   forward, // flip animation
   backward
};

}

@protocol FlipAnimatedViewController <NSObject>
- (void) animationDidFinish : (int) direction;
- (void) animationCancelled;
@end

@interface AnimationDelegate : NSObject

@property (nonatomic) bool flipStartedOnTheLeft;

@property (nonatomic, assign) FlipView *transformView;
@property (nonatomic, assign) NSObject<FlipAnimatedViewController> *controller;

// the duration of the next animation cycle
@property (nonatomic) CGFloat nextDuration;

@property (nonatomic) FlipAnimation::SequenceType sequenceType;
@property (nonatomic) int animationState;
@property (nonatomic) BOOL animationLock;
// shadow layers are created during frame initialization, this setting determines whether or not to animate them
@property (nonatomic) BOOL shadow;
// positive value for adjusting the perspective. Lower the value, greater the
// illusion of depth. Generally ranges between 200 to 2000
@property (nonatomic) int perspectiveDepth;


/* properties for kSequenceControlled */
// positive modifier for input to animation response. Higher the
// sensitivity, greater the response. 10 is an average value
@property (nonatomic) int sensitivity;
// positive modifier for speed of movement after input is removed, you can think of it as gravity
// applied to the frame that moves layers to a resting position. Higher the gravity, faster
// the movement. 3 is an average value
@property (nonatomic) int gravity;

- (id) initWithSequenceType : (FlipAnimation::SequenceType) aType
              directionType : (FlipAnimation::DirectionType) aDirection;

// for triggering animation via kSequenceTriggered or kSequenceAuto
- (BOOL) startAnimation : (FlipAnimation::DirectionType) aDirection;

// for notifying animation delegate that user input has ended in kSequenceControlled
// and it should move to the nearest resting state
- (void) endStateWithSpeed : (CGFloat) aVelocity;

// reset transform and opacity values
- (void) resetTransformValues;

// apply the actual transform
// kSequenceControlled does not use the inbuilt delegate callback during input
- (void) setTransformValue : (CGFloat) aValue delegating : (BOOL) bValue;

// wrapper for 2.5D rotation using explicit CABasicAnimation on the target CALayer
- (void) setTransformProgress : (CGFloat) startTransformValue
                              : (CGFloat) endTransformValue
                              : (CGFloat) duration
                              : (int) aX
                              : (int) aY
                              : (int) aZ
                              : (BOOL) setDelegate
                              : (BOOL) removedOnCompletion
                              : (NSString *) fillMode
                              : (CALayer *) targetLayer;

// wrapper for opacity change using explicit CABasicAnimation on the target CALayer
- (void) setOpacityProgress : (CGFloat) startOpacityValue
                            : (CGFloat) endOpacityValue
                            : (CGFloat) beginTime
                            : (CGFloat) duration
                            : (NSString *) fillMode
                            : (CALayer *) targetLayer;

// callback after delegate is notified that animation has completed, or input has ended
- (void) animationCallback;

@end
