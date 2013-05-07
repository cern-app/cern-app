//
//  StaticInfoItemViewController.h
//  CERN App
//
//  Created by Eamon Ford on 7/17/12.
//  Copyright (c) 2012 CERN. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "MWPhotoBrowser.h"

@interface StaticInfoItemViewController : UIViewController <MWPhotoBrowserDelegate> {
   IBOutlet UIScrollView *scrollView;
   IBOutlet UILabel *descriptionLabel;
   IBOutlet UILabel *titleLabel;
}

@property (nonatomic) IBOutlet UIImageView *imageView;
@property (nonatomic) __weak NSDictionary *staticInfo;
@property (nonatomic) BOOL delayImageLoad;

- (void) setAndPositionInformation;

@end
