//
//  PageContainingViewController.m
//  CERN App
//
//  Created by Eamon Ford on 7/26/12.
//  Copyright (c) 2012 CERN. All rights reserved.
//

//Modified by Timur Pocheptsov to work at least correctly on different devices.
//This crap-code must be re-written later, it's a piece of a ... shame.

#import "StaticInfoSelectorViewController.h"
#import "StaticInfoScrollViewController.h"
#import "AppDelegate.h"
#import "DeviceCheck.h"
#import "Constants.h"

@implementation StaticInfoScrollViewController
@synthesize scrollView, dataSource, popoverController, pageControl;

//________________________________________________________________________________________
- (id) initWithCoder : (NSCoder *) aDecoder
{
    if (self = [super initWithCoder : aDecoder]) {
      //
    }

    return self;
}

//________________________________________________________________________________________
- (StaticInfoItemViewController *) viewControllerForPage : (int) page
{
   UIStoryboard *mainStoryboard = nil;
   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
      mainStoryboard = [UIStoryboard storyboardWithName:@"MainStoryboard_iPhone" bundle : nil];
   else if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
      mainStoryboard = [UIStoryboard storyboardWithName:@"MainStoryboard_iPad" bundle : nil];

   assert(mainStoryboard != nil && "viewControllerForPage:, no storyboard found");

   StaticInfoItemViewController *detailViewController = [mainStoryboard instantiateViewControllerWithIdentifier:kStaticInfoItemViewController];
   assert(detailViewController != nil && "viewControllerForPage:, no StaticInfoItemViewController found in a storyboard");
   
   detailViewController.staticInfo = [self.dataSource objectAtIndex:page];
    
   return detailViewController;
}

//________________________________________________________________________________________
- (void) viewDidLoad
{
   [super viewDidLoad];
   [self refresh];
}

//________________________________________________________________________________________
- (void) viewWillAppear : (BOOL) animated
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        [UIApplication sharedApplication].statusBarHidden = YES;
    }

   //TP: on iPhone devices, this is a BAD time to call positionChildrenWithDuration:,
   //view's geometry is totally screwed up by UIKit.
   if ([DeviceCheck deviceIsiPad])
      [self positionChildrenWithDuration : 0.f];
}

//________________________________________________________________________________________
- (void) viewDidAppear : (BOOL) animated
{
   //Call this only on iPhones, now view's geometry is at least correct(?)
   if (![DeviceCheck deviceIsiPad])
      [self positionChildrenWithDuration : 0.0];
}

//________________________________________________________________________________________
- (void) viewWillDisappear : (BOOL) animated
{
   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
      [UIApplication sharedApplication].statusBarHidden = NO;   
}

//________________________________________________________________________________________
- (void) viewDidUnload
{
   [super viewDidUnload];
   
   for (UIViewController *childViewController in self.childViewControllers) {
      [childViewController.view removeFromSuperview];
      [childViewController removeFromParentViewController];
   }
}

//________________________________________________________________________________________
- (BOOL) shouldAutorotateToInterfaceOrientation : (UIInterfaceOrientation) interfaceOrientation
{
   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
      return YES;
   else
      return interfaceOrientation == UIInterfaceOrientationPortrait;
}

//________________________________________________________________________________________
- (void) willAnimateRotationToInterfaceOrientation : (UIInterfaceOrientation) toInterfaceOrientation duration : (NSTimeInterval) duration
{
   [self positionChildrenWithDuration:duration];
}

//________________________________________________________________________________________
- (void) scrollViewDidScroll : (UIScrollView *) sender
{
   const CGFloat pageWidth = self.scrollView.frame.size.width;
   const int page = floor((self.scrollView.contentOffset.x - pageWidth / 2) / pageWidth) + 1;

   self.pageControl.currentPage = page;
}

//________________________________________________________________________________________
- (void) refresh
{
   for (UIViewController *childViewController in self.childViewControllers) {
      [childViewController.view removeFromSuperview];
      [childViewController removeFromParentViewController];
   }
   
   self.pageControl.numberOfPages = self.dataSource.count;

   for (int i=0; i<self.dataSource.count; i++) {
      StaticInfoItemViewController *detailViewController = [self viewControllerForPage:i];
      [self addChildViewController:detailViewController];
      [self.scrollView addSubview:detailViewController.view];
      [detailViewController didMoveToParentViewController:self];
   }

   [self positionChildrenWithDuration:0.0];
}

//________________________________________________________________________________________
- (void) positionChildrenWithDuration : (NSTimeInterval) duration
{
   [UIView animateWithDuration : duration animations : ^{
      if (![DeviceCheck deviceIsiPad]) {
         const CGFloat deviceViewWidth = 320.f;

         for (NSUInteger i = 0; i < self.childViewControllers.count; ++i) {
            StaticInfoItemViewController *detailViewController = [self.childViewControllers objectAtIndex : i];
            const CGFloat detailViewX = i * deviceViewWidth;
            detailViewController.view.frame = CGRectMake(detailViewX, 0.f, deviceViewWidth, self.scrollView.frame.size.height);
            [detailViewController.view setNeedsDisplay];
         }
   
         self.scrollView.contentSize = CGSizeMake(deviceViewWidth * self.childViewControllers.count, self.scrollView.frame.size.height);
      } else {
         CGFloat detailViewWidth = 0.0;
         CGFloat detailViewHeight = 480.0;
         CGFloat detailViewX = 0.0;

         CGFloat detailViewY = self.scrollView.frame.size.height / 2 - detailViewHeight / 2;
         //Ugly fix for ugly code.
         if (detailViewY < 0.)
            detailViewY = 0.;

         CGFloat detailViewMargin = 0.0;

         for (NSUInteger i = 0; i < self.childViewControllers.count; ++i) {
            StaticInfoItemViewController *detailViewController = [self.childViewControllers objectAtIndex : i];
            detailViewWidth = detailViewController.view.frame.size.width;
            detailViewHeight = detailViewController.view.frame.size.height;

            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
                detailViewMargin = 0;
            } else {
                detailViewMargin = 50.0;
            }

            detailViewX = (detailViewWidth+(2*detailViewMargin))*i;

            detailViewController.view.frame = CGRectMake(detailViewX+detailViewMargin, detailViewY, detailViewWidth, detailViewHeight);
            [detailViewController.view setNeedsDisplay];
         }
      
         self.scrollView.contentSize = CGSizeMake(detailViewX + detailViewWidth + 2 * detailViewMargin, 1.f);
      }
   }];
}

//________________________________________________________________________________________
- (IBAction) categoryButtonTapped : (id)sender
{
   if (!self.popoverController) {
      AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
      StaticInfoSelectorViewController *selectorViewController = [[StaticInfoSelectorViewController alloc] init];
      selectorViewController.tableDataSource = appDelegate.staticInfoDataSource;
      UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:selectorViewController];
      self.popoverController = [[UIPopoverController alloc] initWithContentViewController:navigationController];
   }

   [self.popoverController presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
}

@end