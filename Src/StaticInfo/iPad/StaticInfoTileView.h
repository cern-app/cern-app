//
//  StaticInfoTile.h
//  CERN
//
//  Created by Timur Pocheptsov on 5/7/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <UIKit/UIKit.h>

namespace CernAPP {

enum class StaticInfoTileHint : char {
   none,
   scheme1,//image is on the left or on the top.
   scheme2 //image is on the right or at the bottom.
};

}

@interface StaticInfoTileView : UIView

- (void) setImage : (UIImage *) image;
- (void) setTitle : (NSString *) title;
- (void) setText : (NSString *) text;

- (void) layoutTile;

@property (nonatomic) CernAPP::StaticInfoTileHint layoutHint;

@end
