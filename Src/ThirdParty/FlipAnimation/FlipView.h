#import <UIKit/UIKit.h>

namespace FlipAnimation {

enum class SequenceType : char;
enum class AnimationType : char;
enum class DirectionType : char;

}

@interface FlipView : UIView

// Stack of Animation Frames
// Image data is grouped into Animation Frames, each frame contains the set of images displayed in between sequences
@property (nonatomic, retain) NSMutableArray *imageStackArray;

// view has to know the type of animation to be able to prepare (draw, slice) the animation layers
@property (nonatomic) FlipAnimation::AnimationType animationType;

- (id)initWithAnimationType : (FlipAnimation::AnimationType) aType
                      frame : (CGRect) aFrame;

// method to override for subclasses
- (void) setFrameGeometry : (CGSize) frameSize;
- (void) addFrame : (UIView *) pageView;
- (void) removeAllFrames;
- (void) shiftBackwardWithNewPage : (UIView *) pageView;
- (void) shiftForwardWithNewPage : (UIView *) pageView;

- (void)rearrangeLayers : (FlipAnimation::DirectionType) aDirectionType : (NSUInteger) step;

//- (CALayer *) layerWithFrame : (CGRect) aFrame;

@end
