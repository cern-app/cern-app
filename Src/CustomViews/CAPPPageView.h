//
//  CAPPPageView.h
//  infinite_page_control
//
//  Created by Timur Pocheptsov on 16/12/13.
//  Copyright (c) 2013 Timur Pocheptsov. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CAPPPageView : UIView

+ (CGFloat) defaultCellWidth;

@property (nonatomic) NSUInteger numberOfPages;
@property (nonatomic) NSUInteger activePage;

@end
