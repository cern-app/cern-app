//
//  StaticInfoTileViewController.m
//  CERN
//
//  Created by Timur Pocheptsov on 5/8/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <algorithm>

#import "StaticInfoTileViewController.h"
#import "StaticInfoPageView.h"

@implementation StaticInfoTileViewController {
   BOOL viewDidAppear;

   //NSOperationQueue *opQueue;
   //NSInvocationOperation *imageCreateOp;
}

//________________________________________________________________________________________
- (id) initWithCoder : (NSCoder *) aDecoder
{
   if (self = [super initWithCoder : aDecoder]) {
      viewDidAppear = NO;
   }
   
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
   }
}

#pragma mark - Overriders for TileViewController's methods.

//________________________________________________________________________________________
- (void) loadVisiblePageData
{
   /*
   if (!downloaders)
      downloaders = [[NSMutableDictionary alloc] init];

   NSNumber * const key = [NSNumber numberWithUnsignedInteger : currPage.pageNumber];
   if (downloaders[key])
      return;
   
   NSMutableArray * const thumbnails = [[NSMutableArray alloc] init];
   const NSRange range = currPage.pageRange;
   for (NSUInteger i = range.location, e = range.location + range.length; i < e; ++i) {
      MWFeedItem * const article = (MWFeedItem *)dataItems[i];
      if (!article.image) {
         //May be, we already have a downloader for this item?
         NSString * body = article.content;
         if (!body)
            body = article.summary;

         if (NSString * const urlString = [NewsTableViewController firstImageURLFromHTMLString : body]) {
            KeyVal * const newThumbnail = [[KeyVal alloc] init];
            newThumbnail.key = [NSIndexPath indexPathForRow : i inSection : currPage.pageNumber];
            newThumbnail.val = urlString;
            [thumbnails addObject : newThumbnail];
         }
      }
   }
   
   if (!thumbnails.count) {
      //Let's check, if we have an image in some article, but no image in the corresponding tile.
      bool needUpdate = false;
      for (NSUInteger i = range.location, e = range.location + range.length; i < e; ++i) {
         MWFeedItem * const article = (MWFeedItem *)dataItems[i];
         if (article.image && ![currPage tileHasThumbnail : i - range.location]) {
            needUpdate = true;
            [currPage setThumbnail : article.image forTile : i - range.location doLayout : NO];
         }
      }
      
      if (needUpdate) {
         [currPage layoutTiles];
         [flipView replaceCurrentFrame : currPage];
      }
   } else {
      PageThumbnailDownloader * const newDownloader = [[PageThumbnailDownloader alloc] initWithItems : thumbnails];
      [downloaders setObject:newDownloader forKey : key];
      newDownloader.delegate = self;
      [newDownloader startDownload];
   }*/
}

#pragma mark - UI

/*
//________________________________________________________________________________________
- (void) addNavBarSpinner
{
   navBarSpinner = [[UIActivityIndicatorView alloc] initWithFrame : CGRectMake(0.f, 0.f, 20.f, 20.f)];
   UIBarButtonItem * barButton = [[UIBarButtonItem alloc] initWithCustomView : navBarSpinner];
   // Set to Left or Right
   self.navigationItem.rightBarButtonItem = barButton;
   [navBarSpinner startAnimating];
}

//________________________________________________________________________________________
- (void) hideNavBarSpinner
{
   if (navBarSpinner) {
      [navBarSpinner stopAnimating];
      navBarSpinner = nil;
      self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                                initWithBarButtonSystemItem : UIBarButtonSystemItemRefresh
                                                target : self action : @selector(reloadPageFromRefreshControl)];
   }
}
*/


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
   //TODO
   //[NSNotificationCenter defaultCenter] addObserver:<#(NSObject *)#> forKeyPath:<#(NSString *)#> options:<#(NSKeyValueObservingOptions)#> context:<#(void *)#>
}

//________________________________________________________________________________________
- (void) loadImages
{
   for (NSUInteger i = 0, e = dataItems.count; i < e; ++i) {
      NSMutableDictionary * const itemDict = (NSMutableDictionary *)dataItems[i];
      UIImage * const newImage = [UIImage imageNamed : (NSString *)itemDict[@"Image"]];
      if (!newImage)
         continue;

      [itemDict setObject : newImage forKey : @"Thumbnail"];
   }
}

@end
