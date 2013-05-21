//
//  AnimatedStackLayout.h
//  CERN
//
//  Created by Timur Pocheptsov on 5/21/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AnimatedStackLayout : UICollectionViewFlowLayout

//The point to which the stack collapses.
@property (nonatomic) CGPoint stackCenter;

//0.f means completely stacked, 1.f results in the default FlowLayout.
@property (nonatomic) CGFloat stackFactor;

@end
