//
//  CAPPPageControlPegView.h
//  CERN
//
//  Created by Timur Pocheptsov on 19/12/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CAPPPageControlPegView : UIView

+ (CGRect) pegFrame;

@property (nonatomic) NSUInteger activePage;

@end
