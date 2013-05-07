//
//  PageContainingViewController.h
//  CERN App
//
//  Created by Eamon Ford on 7/26/12.
//  Copyright (c) 2012 CERN. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface StaticInfoScrollViewController : UIViewController <UIScrollViewDelegate> {
   IBOutlet UIScrollView *scrollView;
   IBOutlet UIPageControl *pageControl;
}

@property (nonatomic) __weak NSArray *dataSource;

- (IBAction) revealMenu : (id) sender;

@end
