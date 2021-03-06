//
//  StaticInfoTileViewController.m
//  CERN
//
//  Created by Timur Pocheptsov on 5/8/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <algorithm>

#import "StaticInfoTileViewController.h"
#import "StaticInfoTileView.h"
#import "StaticInfoPageView.h"

@implementation StaticInfoTileViewController {
   BOOL viewDidAppear;
   NSUInteger selectedItem;
   //NSOperationQueue *opQueue;
   //NSInvocationOperation *imageCreateOp;
}

//________________________________________________________________________________________
- (id) initWithCoder : (NSCoder *) aDecoder
{
   if (self = [super initWithCoder : aDecoder])
      viewDidAppear = NO;

   return self;
}

//________________________________________________________________________________________
- (void) dealloc
{
   [[NSNotificationCenter defaultCenter] removeObserver : self];
}

#pragma mark - data source.

//________________________________________________________________________________________
- (void) setDataSource : (NSArray *) data
{
   assert(data != nil && "setDataSource:, parameter 'data' is nil");
   dataItems = (NSMutableArray *)[data mutableCopy];
   
   dataItems = [[NSMutableArray alloc] init];
   for (id item in data) {
      assert([item isKindOfClass : [NSDictionary class]] &&
             "setDataSource:, item has a wrong type");
      [dataItems addObject : [(NSDictionary *)item mutableCopy]];
   }
}

#pragma mark - Overriders for UIViewController methods.

//________________________________________________________________________________________
- (void) viewDidLoad
{
   [super viewDidLoad];
   
   [self createPages];
   [self addTileTapObserver];
   
   [self.view addSubview : currPage];
   [self.view bringSubviewToFront : currPage];
}

//________________________________________________________________________________________
- (void) viewDidAppear : (BOOL) animated
{
   [super viewDidAppear : animated];

   //By this point data Source must be initialized by the external code.
   assert(dataItems != nil && "viewDidAppear:, dataItems was not set correctly");

   //viewDidAppear can be called many times: the first time when controller
   //created and view loaded, next time - for example, when article detailed view
   //controller is poped from the navigation stack.

   if (!viewDidAppear) {
      viewDidAppear = YES;
      [self loadImages];
      [self setPagesData];
      
      [self layoutPages : YES];
      [self layoutFlipView];
      [self layoutPanRegion];
      
      if (nPages > 1)
         [self showRightFlipHint];
   }
}

//________________________________________________________________________________________
- (BOOL) canInterruptWithAlert
{
   return !flipAnimator.animationLock;
}

#pragma mark - Overriders for TileViewController's methods.

//________________________________________________________________________________________
- (void) loadVisiblePageData
{
   //Noop at the moment.
}

#pragma mark - ConnectionController protocol.

//________________________________________________________________________________________
- (void) cancelAnyConnections
{
   //TODO!!!
}

#pragma mark - Aux. functions.

//________________________________________________________________________________________
- (void) createPages
{
   prevPage = [[StaticInfoPageView alloc] initWithFrame : CGRect()];
   currPage = [[StaticInfoPageView alloc] initWithFrame : CGRect()];
   nextPage = [[StaticInfoPageView alloc] initWithFrame : CGRect()];
}

//________________________________________________________________________________________
- (void) addTileTapObserver
{
   [[NSNotificationCenter defaultCenter] addObserver : self selector : @selector(tileSelected:) name : CernAPP::StaticInfoItemNotification object : nil];
}

//________________________________________________________________________________________
- (void) loadImages
{
   for (NSUInteger i = 0, e = dataItems.count; i < e; ++i) {
      NSMutableDictionary * const itemDict = (NSMutableDictionary *)dataItems[i];
      UIImage * const newImage = [UIImage imageWithContentsOfFile : [[NSBundle mainBundle] pathForResource : (NSString *)itemDict[@"Image"] ofType : nil]];
      if (!newImage)
         continue;

      [itemDict setObject : newImage forKey : @"Thumbnail"];
   }
}

#pragma mark - User interactions.

//________________________________________________________________________________________
- (void) tileSelected : (NSNotification *) notification
{
   assert(notification != nil && "tileSelected:, parameter 'notification' is nil");
   assert([notification.object isKindOfClass : [NSNumber class]] &&
          "tileSelected:, notification.object has a wrong type");

   selectedItem = [(NSNumber *)notification.object unsignedIntegerValue];
   assert(selectedItem < dataItems.count && "tileSelected:, index is out of bounds");
   
   MWPhotoBrowser * const browser = [[MWPhotoBrowser alloc] initWithDelegate : self];
   UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController : browser];
   navigationController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
   [self presentViewController : navigationController animated : YES completion : nil];
}

#pragma mark - MWPhotoBrowserDelegate methods

//________________________________________________________________________________________
- (void) photoBrowserWillDismiss
{
   //NOOP, nobody cares.
}

//________________________________________________________________________________________
- (NSUInteger) numberOfPhotosInPhotoBrowser : (MWPhotoBrowser *) photoBrowser
{
   return 1;
}

//________________________________________________________________________________________
- (MWPhoto *) photoBrowser : (MWPhotoBrowser *) photoBrowser photoAtIndex : (NSUInteger) index
{
   assert(((NSDictionary *)dataItems[selectedItem])[@"Thumbnail"] != nil &&
          "photoBrowser:photoAtIndex:, no image found");
   assert(selectedItem < dataItems.count &&
          "photoBrowser:photoAtIndex:, selected item is out of bounds");
   NSDictionary * const itemDict = (NSDictionary *)dataItems[selectedItem];
   return [MWPhoto photoWithImage : (UIImage *)itemDict[@"Thumbnail"]];
}

@end
