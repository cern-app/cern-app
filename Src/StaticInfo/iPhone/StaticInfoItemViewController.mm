//
//  StaticInfoViewController.m
//  CERN App
//
//  Created by Eamon Ford on 7/17/12.
//  Copyright (c) 2012 CERN. All rights reserved.
//

#import <cassert>

#import <QuartzCore/QuartzCore.h>

#import "StaticInfoItemViewController.h"
#import "DeviceCheck.h"

@implementation StaticInfoItemViewController

@synthesize staticInfo, imageView, delayImageLoad;

//________________________________________________________________________________________
- (id)initWithNibName : (NSString *) nibNameOrNil bundle : (NSBundle *) nibBundleOrNil
{
   return self = [super initWithNibName : nibNameOrNil bundle : nibBundleOrNil];
}

//________________________________________________________________________________________
- (void) viewDidLoad
{
   [super viewDidLoad];
   
   scrollView.backgroundColor = [UIColor colorWithWhite : 0.9f alpha : 1.f];

   UITapGestureRecognizer * const singleFingerTap = [[UITapGestureRecognizer alloc] initWithTarget : self action : @selector(handleSingleTap:)];
   [self.view addGestureRecognizer : singleFingerTap];
}

//________________________________________________________________________________________
- (void) viewDidLayoutSubviews
{
   [self setAndPositionInformation];
}

//________________________________________________________________________________________
- (void) setAndPositionInformation
{
   // Set the image, and position it right below the title label
   const CGRect baseFrame = scrollView.frame;
   
   if (!delayImageLoad) {
      assert([[staticInfo objectForKey:@"Image"] isKindOfClass:[NSString class]] &&
             "setAndPositionInformation, 'Image' is either not found or has a wrong type");

      imageView.image = [UIImage imageNamed : (NSString *)[self.staticInfo objectForKey : @"Image"]];
   }

   imageView.contentMode = UIViewContentModeScaleAspectFill;
   imageView.clipsToBounds = YES;
   imageView.frame = CGRectMake(0.f, 0.f, baseFrame.size.width, baseFrame.size.height / 2.);

   // Set the title label and resize it accordingly
   assert([[staticInfo objectForKey : @"Title"] isKindOfClass:[NSString class]] &&
          "setAndPositionInformation, 'Title' is either not found or has a wrong type");
   NSString * const title = (NSString *)[staticInfo objectForKey : @"Title"];
   titleLabel.text = title;

   const CGSize titleSize = [title sizeWithFont : titleLabel.font constrainedToSize : CGSizeMake(titleLabel.frame.size.width, CGFLOAT_MAX)];

   assert([[staticInfo objectForKey : @"Description"] isKindOfClass : [NSString class]] &&
          "setAndPositionInformation, 'Description' is either not found or has a wrong type");
   
   NSString * const description = (NSString *)[self.staticInfo objectForKey : @"Description"];
   const CGSize descriptionSize = [description sizeWithFont : descriptionLabel.font constrainedToSize : CGSizeMake(descriptionLabel.frame.size.width, CGFLOAT_MAX)];

   titleLabel.frame = CGRectMake(titleLabel.frame.origin.x, imageView.frame.size.height + 8.f, titleLabel.frame.size.width, titleSize.height);
   // Set the description label and resize it accordingly, and also position it right below the image view
   descriptionLabel.frame = CGRectMake(descriptionLabel.frame.origin.x, titleLabel.frame.origin.y + titleLabel.frame.size.height + 8.0f, descriptionLabel.frame.size.width, descriptionSize.height);
   descriptionLabel.text = description;

   // Set the content size of the scrollview
   scrollView.contentSize = CGSizeMake(scrollView.frame.size.width, descriptionLabel.frame.origin.y + descriptionLabel.frame.size.height);
}

//________________________________________________________________________________________
- (void) handleSingleTap : (UITapGestureRecognizer *) recognizer 
{
   const CGPoint touchLocation = [recognizer locationInView : self.view];
   // If the photo was tapped, display it fullscreen
   if (CGRectContainsPoint(imageView.frame, touchLocation)) {
   

      MWPhotoBrowser * const browser = [[MWPhotoBrowser alloc] initWithDelegate : self];
      UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController : browser];
      navigationController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;

      [self presentViewController : navigationController animated : YES completion : nil];
   }
}

#pragma mark - MWPhotoBrowserDelegate methods

//________________________________________________________________________________________
- (NSUInteger) numberOfPhotosInPhotoBrowser : (MWPhotoBrowser *) photoBrowser
{
   return 1;
}

//________________________________________________________________________________________
- (MWPhoto *) photoBrowser : (MWPhotoBrowser *) photoBrowser photoAtIndex : (NSUInteger) index
{
   return [MWPhoto photoWithImage : [UIImage imageNamed : [staticInfo objectForKey : @"Image"]]];
}

//________________________________________________________________________________________
- (BOOL) shouldAutorotate
{
   return NO;
}

//________________________________________________________________________________________
- (NSUInteger) supportedInterfaceOrientations
{
   return  UIInterfaceOrientationMaskPortrait;
}

@end
