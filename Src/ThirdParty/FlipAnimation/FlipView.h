//
//  FlipView.h
//  flipboard_anim
//
//  Created by Timur Pocheptsov on 4/25/13.
//  Copyright (c) 2013 Timur Pocheptsov. All rights reserved.
//

#import <UIKit/UIKit.h>

namespace FlipAnimation {

enum class SequenceType : char;
enum class AnimationType : char;
enum class DirectionType : char;

}

@interface FlipView : UIView {

    UIImage *templateImage;
    
    // size of the view determines size of all Animation Frames
    float templateWidth;
    float templateHeight;
    
    // number of logical parts in an Animation Frame
    int imageUnitQuantity; 
    
}

// Stack of Animation Frames
// Image data is grouped into Animation Frames, each frame contains the set of images displayed in between sequences
@property (nonatomic, retain) NSMutableArray *imageStackArray;

// set inset to restrict text frame size
@property (nonatomic) CGPoint textInset;
// set offset from position to align text
@property (nonatomic) CGPoint textOffset;
// font size (different from UILabel font size property)
@property (nonatomic) float fontSize;
// provide a font from plist or use inbuilt fonts
// if the rendering is very slow, change the font
@property (nonatomic, assign) NSString *font;
// font alignment
@property (nonatomic, assign) NSString *fontAlignment;
// truncation mode to set for CATextLayer
@property (nonatomic, assign) NSString *textTruncationMode;

// view has to know the type of animation to be able to prepare (draw, slice) the animation layers
@property (nonatomic) FlipAnimation::AnimationType animationType;

- (id)initWithAnimationType:(FlipAnimation::AnimationType)aType
                      frame:(CGRect)aFrame;

// method to override for subclasses
- (void) addPage : (UIView *) pageView;
- (void) shiftBackwardWithNewPage : (UIView *) pageView;
- (void) shiftForwardWithNewPage : (UIView *) pageView;

- (CALayer *)layerWithFrame:(CGRect)aFrame;

- (void)rearrangeLayers:(FlipAnimation::DirectionType)aDirectionType :(int)step;

@end
