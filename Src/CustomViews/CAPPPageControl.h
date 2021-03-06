//
//  CAPPPageControl.h
//  Infinite page control for CERN.app
//
//  Created by Timur Pocheptsov on 16/12/13.
//

#import <UIKit/UIKit.h>

@class CAPPPageControl;

@protocol CAPPPageControlDelegate
@optional

- (void) pageControlDidEndAnimating : (CAPPPageControl *) control;

@end

@interface CAPPPageControl : UIView<UIScrollViewDelegate>

@property (nonatomic, weak) NSObject<CAPPPageControlDelegate> *delegate;
@property (nonatomic) BOOL animating;
@property (nonatomic) NSUInteger numberOfPages;
@property (nonatomic) NSUInteger activePage;

@end
