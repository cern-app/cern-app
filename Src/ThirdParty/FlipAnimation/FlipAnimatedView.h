//
//  FlipAnimatedView.h
//  flipboard_anim
//
//  Created by Timur Pocheptsov on 4/25/13.
//  Copyright (c) 2013 Timur Pocheptsov. All rights reserved.
//

#import <Foundation/Foundation.h>

namespace FlipAnimation {

enum class AnimationType : char;
enum class DirectionType : char;

}

@protocol FlipAnimatedView <NSObject>

@required

@property (nonatomic) FlipAnimation::AnimationType animationType;
@property (nonatomic, retain) NSMutableArray *imageStackArray;

- (void) rearrangeLayers : (FlipAnimation::DirectionType) aDirectionType : (int) step;


@end
