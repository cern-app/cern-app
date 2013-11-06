//
//  PageContainingViewController.m
//  CERN App
//
//  Created by Eamon Ford on 7/26/12.
//  Copyright (c) 2012 CERN. All rights reserved.
//

//Modified by Timur Pocheptsov.


#import "StaticInfoScrollViewController.h"
#import "StaticInfoItemViewController.h"
#import "ECSlidingViewController.h"
#import "StoryboardIdentifiers.h"
#import "DeviceCheck.h"
#import "KeyVal.h"


@implementation StaticInfoScrollViewController

@synthesize dataSource;

//________________________________________________________________________________________
- (id) initWithCoder : (NSCoder *) aDecoder
{
   return self = [super initWithCoder : aDecoder];
}

//________________________________________________________________________________________
- (StaticInfoItemViewController *) viewControllerForPage : (NSUInteger) page
{
   using namespace CernAPP;

   assert(page < dataSource.count && "viewControllerForPage:, parameter 'page' is out of bounds");

   UIStoryboard * const mainStoryboard = [UIStoryboard storyboardWithName :
                                          CernAPP::SystemVersionGreaterThanOrEqualTo(@"7.0") ? @"iPhone_iOS7" : @"iPhone"
                                          bundle : nil];
   
   StaticInfoItemViewController * const detailViewController = [mainStoryboard instantiateViewControllerWithIdentifier : StaticInfoItemViewControllerID];
   if (page > 2)
      detailViewController.delayImageLoad = YES;
   
   detailViewController.staticInfo = [dataSource objectAtIndex : page];
    
   return detailViewController;
}

//________________________________________________________________________________________
- (void) viewDidLoad
{
   [super viewDidLoad];
   
   //Create children views for static info entries and add them into the scroll view.
   assert(dataSource != nil && dataSource.count != 0 &&
          "viewDidLoad:, dataSource is either nil or empty");
   
   pageControl.numberOfPages = dataSource.count;
   scrollView.backgroundColor = [UIColor clearColor];
   self.view.backgroundColor = [UIColor blackColor];
   
   if (CernAPP::SystemVersionGreaterThanOrEqualTo(@"7.0")) {
      pageControl.pageIndicatorTintColor = [UIColor blackColor];
      pageControl.currentPageIndicatorTintColor = [UIColor colorWithRed : 107 / 255.f green : 141 / 255.f blue : 191 / 255.f alpha : 1.f];
   }

   for (NSUInteger i = 0, e = dataSource.count; i < e; ++i) {
      StaticInfoItemViewController *detailViewController = [self viewControllerForPage: i];
      [self addChildViewController : detailViewController];
      [scrollView addSubview : detailViewController.view];
      [detailViewController didMoveToParentViewController : self];
   }
}

//________________________________________________________________________________________
- (void) viewDidAppear:(BOOL)animated
{
   [super viewDidAppear : animated];
   
   if (scrollView) {
      if (dataSource.count > 1)
         [self.slidingViewController.panGesture requireGestureRecognizerToFail : scrollView.panGestureRecognizer];
   }
}

//________________________________________________________________________________________
- (void) viewDidLayoutSubviews
{
   //Now layout static info item views in a scrollview.
   const CGFloat deviceViewWidth = scrollView.frame.size.width;

   for (NSUInteger i = 0, e = self.childViewControllers.count; i < e; ++i) {
      StaticInfoItemViewController *detailViewController = (StaticInfoItemViewController *)[self.childViewControllers objectAtIndex : i];
      const CGFloat detailViewX = i * deviceViewWidth;
      detailViewController.view.frame = CGRectMake(detailViewX, 0.f, deviceViewWidth, scrollView.frame.size.height);
      [detailViewController.view setNeedsDisplay];
   }

   scrollView.contentSize = CGSizeMake(deviceViewWidth * self.childViewControllers.count, scrollView.frame.size.height);
   
   for (NSUInteger i = 2, e = dataSource.count; i < e; ++i)
      [self performSelectorInBackground : @selector(loadImageInBackgroundThread:)
            withObject : [NSNumber numberWithInteger : NSInteger(i)]];
}

//________________________________________________________________________________________
- (void) loadImageInBackgroundThread : (id) obj
{
   assert([obj isKindOfClass : [NSNumber class]] &&
          "loadImageInBackgroundThread:, parameter 'obj' is either nil or has a wrong type");
   
   const NSInteger index = [(NSNumber *)obj integerValue];
   assert(index < dataSource.count && "loadImageInBackgroundThread:, index is out of bounds");
   assert([dataSource[index] isKindOfClass : [NSDictionary class]] &&
          "loadImageInBackgroundThread:, NSDictionary expected");

   NSDictionary * const imageDict = (NSDictionary *)dataSource[index];

   assert([imageDict[@"Image"] isKindOfClass : [NSString class]] &&
          "loadImageInBackgroundThread:, 'Image' not found or has a wrong type");

   UIImage * const newImage = [UIImage imageWithContentsOfFile : [[NSBundle mainBundle] pathForResource : (NSString *)imageDict[@"Image"] ofType : nil]];
   KeyVal * const retPair = [[KeyVal alloc] init];
   retPair.key = obj;
   retPair.val = newImage;
   
   [self performSelectorOnMainThread : @selector(setItemImage:) withObject : retPair waitUntilDone : NO];
}

//________________________________________________________________________________________
- (void) setItemImage : (id) obj
{
   assert([obj isKindOfClass:[KeyVal class]] &&
          "setItemImage:, parameter 'obj' is either nil or has a wrong type");
   
   KeyVal * const pair = (KeyVal *)obj;
   assert([pair.key isKindOfClass : [NSNumber class]] &&
          "setItemImage:, pair.key is either nil or has a wrong type");
   assert([pair.val isKindOfClass : [UIImage class]] &&
          "setItemImage:, pair.val is etiher nil or has a wrong type");
   
   const NSInteger index = [(NSNumber *)pair.key integerValue];
   assert(index < dataSource.count && "setItemImage:, pair.key is out of bounds");
   
   StaticInfoItemViewController * const controller = (StaticInfoItemViewController *)self.childViewControllers[index];
   controller.imageView.image = (UIImage *)pair.val;
}

//________________________________________________________________________________________
- (void) scrollViewDidScroll : (UIScrollView *) sender
{
   const CGFloat pageWidth = scrollView.frame.size.width;
   const int page = floor((scrollView.contentOffset.x - pageWidth / 2) / pageWidth) + 1;
   assert(page >= 0 && page < self.childViewControllers.count && "scrollViewDidScroll:, page is out of bounds");

   pageControl.currentPage = page;
}

//________________________________________________________________________________________
- (IBAction) revealMenu : (id) sender
{
#pragma unused(sender)
   [self.slidingViewController anchorTopViewTo : ECRight];
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
