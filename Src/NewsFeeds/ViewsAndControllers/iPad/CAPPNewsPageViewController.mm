//
//  CAPPNewsPageViewController.m
//  CERN
//
//  Created by Timur Pocheptsov on 18/12/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <cassert>
#import <cstdlib>

#import "CAPPNewsPageViewController.h"
#import "ECSlidingViewController.h"
#import "MenuViewController.h"
#import "FeedItemTileView.h"
#import "FeedPageView.h"
#import "Reachability.h"
#import "AppDelegate.h"
#import "APNHintView.h"
#import "MWFeedItem.h"
#import "FeedCache.h"


@implementation CAPPNewsPageViewController {
   BOOL viewDidAppear;

   UIActivityIndicatorView *navBarSpinner;
   Reachability *internetReach;
}

@synthesize feedCacheID, apnID, apnItems;

//________________________________________________________________________________________
- (BOOL) hasConnection
{
   assert(internetReach != nil && "hasConnection, internetReach is nil");

   return [internetReach currentReachabilityStatus] != CernAPP::NetworkStatus::notReachable;
}

#pragma mark - "Constructors/destructors".

//________________________________________________________________________________________
- (instancetype) initWithCoder : (NSCoder *) aDecoder
{
   if (self = [super initWithCoder : aDecoder]) {
      downloaders = nil;
      feedCache = nil;
      viewDidAppear = NO;
   
      navBarSpinner = nil;
      
      internetReach = [Reachability reachabilityForInternetConnection];
      apnItems = 0;
   }
   
   return self;
}

//________________________________________________________________________________________
- (void) dealloc
{
   [[NSNotificationCenter defaultCenter] removeObserver : self];
}

#pragma mark - View lifecycle and related methods.

//________________________________________________________________________________________
- (BOOL) initTilesFromDBCache
{
   assert(feedCacheID != nil && "initTilesFromDBCache, invalid feedCacheID");

   if ((feedCache = CernAPP::ReadFeedCache(feedCacheID))) {
      //Set the data from the cache at the beginning!
      dataItems = CernAPP::ConvertFeedCache(feedCache);
      [self setPagesData];
      //
      self.pageControl.numberOfPages = nPages;
      //
      return YES;
   }
   
   return NO;
}

//________________________________________________________________________________________
- (BOOL) initTilesFromAppCache
{
   assert(feedCacheID != nil && "initTilesFromAppCache, feedCacheID is invalid");
   assert([[UIApplication sharedApplication].delegate isKindOfClass : [AppDelegate class]] &&
          "initTilesFromAppCache, app delegate has a wrong type");
   
   if (NSObject * const cache = [(AppDelegate *)[UIApplication sharedApplication].delegate cacheForKey : feedCacheID]) {
      assert([cache isKindOfClass : [NSMutableArray class]] &&
             "initTilesFromAppCache, cached object has a wrong type");
   
      dataItems = (NSMutableArray *)cache;
      [self setPagesData];
      //
      self.pageControl.numberOfPages = nPages;
      //
   }

   return dataItems != nil;//no ptr to BOOL conversion.
}

//________________________________________________________________________________________
- (void) viewDidLoad
{
   [super viewDidLoad];
   
   CernAPP::AddSpinner(self);
   CernAPP::HideSpinner(self);
   
   [self createPages];
   [self addTileTapObserver];
   
   [self.parentScroll addSubview : currPage];
   [self.parentScroll addSubview : nextPage];
   [self.parentScroll addSubview : prevPage];
}

//________________________________________________________________________________________
- (void) viewDidAppear : (BOOL) animated
{
   [super viewDidAppear : animated];

   //viewDidAppear can be called many times: the first time when controller
   //created and view loaded, next time - for example, when article detailed view
   //controller is poped from the navigation stack.

   if (!viewDidAppear) {
      viewDidAppear = YES;
      
      if ([self initTilesFromAppCache]) {
#warning "viewDidAppear:, show apn hints!"
         //[self showAPNHints];
         //[self layoutFeedViews];
         //
         [self layoutFeedViews];
         //
         [self loadVisiblePageData];
         
         return;//No need to refresh.
      }

      (void)[self initTilesFromDBCache];
      [self refresh];
   }
#warning "viewDidAppear:, show apn hints!"
//   [self showAPNHints];
}

#pragma mark - Refresh and related logic.

//________________________________________________________________________________________
- (void) layoutFeedViews
{
   [self layoutPages : YES];
   self.pageControl.numberOfPages = nPages;
}

//________________________________________________________________________________________
- (void) refresh
{
#warning "refresh, TO BE IMPLEMENTED"
}

#pragma mark - Aux. methods which can be overriden.

//________________________________________________________________________________________
- (void) createPages
{
   prevPage = [[FeedPageView alloc] initWithFrame : CGRect()];
   currPage = [[FeedPageView alloc] initWithFrame : CGRect()];
   nextPage = [[FeedPageView alloc] initWithFrame : CGRect()];
}

//________________________________________________________________________________________
- (void) addTileTapObserver
{
   [[NSNotificationCenter defaultCenter] addObserver : self selector : @selector(articleSelected:) name : CernAPP::feedItemSelectionNotification object : nil];
}

#pragma mark - APNEnabledController and aux. methods.
/*
//________________________________________________________________________________________
- (void) setApnItems : (NSUInteger) nItems
{
   if (nItems) {
      apnItems = nItems;
      if (viewDidAppear)
         [self showAPNHints];
   } else if (viewDidAppear) {
      [self hideAPNHints];
   } else
      apnItems = 0;
}

//________________________________________________________________________________________
- (void) showAPNHints
{
   if (!apnItems)
      return;
   
   if (!navBarSpinner.isAnimating) {
      //First, let's check if we already have this item in a feed, if yes, we just remove all apn hints
      //and pretend there is nothing really new.
      assert([[UIApplication sharedApplication].delegate isKindOfClass : [AppDelegate class]] &&
             "showAPNHints, app delegate has a wrong type");
      AppDelegate * const appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
      NSString * const apnHash = [appDelegate APNHashForFeed : apnID];
      if (apnHash) {
         //Well, the version wich accepts NSArray is not visible here,
         //but to be sure it's never called (since the bulletin has array of array,
         //not array of feed items, for example).
         if (CernAPP::FindItem(apnHash, (NSObject *)dataItems)) {
            //Ooops, cached, seen already.
            [self hideAPNHints];
            return;
         }
      }
      //
      APNHintView * apnHint = nil;
      if ([self.navigationItem.rightBarButtonItem.customView isKindOfClass : [APNHintView class]]) {
         apnHint = (APNHintView *)self.navigationItem.rightBarButtonItem.customView;
      } else {
         apnHint = [[APNHintView alloc] initWithFrame : CGRectMake(0.f, 0.f, 20.f, 20.f)];
         UIBarButtonItem * const barButton = [[UIBarButtonItem alloc] initWithCustomView : apnHint];
         self.navigationItem.rightBarButtonItem = barButton;
      }

      apnHint.delegate = self;
      apnHint.count = apnItems;
      //
   }
}

//________________________________________________________________________________________
- (void) hideAPNHints
{
   assert([[UIApplication sharedApplication].delegate isKindOfClass : [AppDelegate class]] &&
          "hideAPNHints, app delegate has a wrong type");
   [(AppDelegate *)[UIApplication sharedApplication].delegate removeAPNHashForFeed : apnID];

   if (!apnItems)
      return;
   
   assert([self.slidingViewController.underLeftViewController isKindOfClass : [MenuViewController class]] &&
          "hideAPNHints, underLeftViewController has a wrong type");
   MenuViewController * const mvc = (MenuViewController *)self.slidingViewController.underLeftViewController;

   [mvc removeNotifications : apnItems forID : apnID];
   apnItems = 0;

   if ([self.navigationItem.rightBarButtonItem.customView isKindOfClass : [APNHintView class]]) {
      self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                                initWithBarButtonSystemItem : UIBarButtonSystemItemRefresh
                                                target : self action : @selector(refresh:)];
   }
}

//________________________________________________________________________________________
- (void) hintTapped
{
   if (parserOp)
      return;

   if (![self hasConnection]) {
      CernAPP::ShowErrorAlert(@"Please, check network", @"Close");
      return;
   }

   [self cancelAllImageDownloaders];
   [self.noConnectionHUD hide : YES];

   [self addNavBarSpinner];
   [self startFeedParser];
}
*/

#pragma mark - UI.

- (IBAction) refresh : (id) sender
{

}

#pragma mark - Aux. methods.

//________________________________________________________________________________________
- (void) cacheInAppDelegate
{
   assert(feedCacheID != nil && "cacheInAppDelegate, feedCacheID is invalid");
   assert([[UIApplication sharedApplication].delegate isKindOfClass : [AppDelegate class]] &&
          "cacheInAppDelegate, app delegate has a wrong type");
   
   AppDelegate * const appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
   [appDelegate cacheData : dataItems withKey : feedCacheID];
}

//________________________________________________________________________________________
- (void) setTilesLayoutHints
{
   for (MWFeedItem *item in dataItems) {
      item.wideImageOnTop = std::rand() % 2;
      item.imageCut = std::rand() % 4;
   }
}


@end
