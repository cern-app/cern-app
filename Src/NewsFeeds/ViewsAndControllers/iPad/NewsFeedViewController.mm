//
//  NewsFeedViewController.m
//  CERN
//
//  Created by Timur Pocheptsov on 4/17/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <cstdlib>
#import <cassert>

#import "ArticleDetailViewController.h"
#import "ECSlidingViewController.h"
#import "NewsFeedViewController.h"
#import "StoryboardIdentifiers.h"
#import "MenuViewController.h"
#import "ApplicationErrors.h"
#import "FeedItemTileView.h"
#import "CAPPPageControl.h"
#import "Reachability.h"
#import "FeedPageView.h"
#import "MWFeedParser.h"
#import "DeviceCheck.h"
#import "AppDelegate.h"
#import "APNHintView.h"

//TODO: instead of TwitterAPI.h must be Details.h
#import "TwitterAPI.h"

#import "URLHelpers.h"
#import "MWFeedItem.h"
#import "FeedCache.h"
#import "FlipView.h"
#import "APNUtils.h"
#import "KeyVal.h"

@implementation NewsFeedViewController {
   BOOL viewDidAppear;
   UIActivityIndicatorView *navBarSpinner;
   Reachability *internetReach;
   
   //The queue with only one operation - parsing.
   NSOperationQueue *parserQueue;
   
   NSString *feedURLString;
   NSArray *feedFilters;
   
   
   //If we are in the process of the flip animation,
   //do not reload/re-create
   BOOL flipRefreshDelayed;
}

@synthesize feedCacheID, apnID, apnItems;

#pragma mark - Reachability.

//________________________________________________________________________________________
- (BOOL) hasConnection
{
   assert(internetReach != nil && "hasConnection, internetReach is nil");

   return [internetReach currentReachabilityStatus] != CernAPP::NetworkStatus::notReachable;
}

#pragma mark - Life cycle.

//________________________________________________________________________________________
- (id) initWithCoder : (NSCoder *) aDecoder
{
   if (self = [super initWithCoder : aDecoder]) {
      downloaders = nil;
      feedCache = nil;
      viewDidAppear = NO;
   
      navBarSpinner = nil;
      
      internetReach = [Reachability reachabilityForInternetConnection];
      
      parserQueue = [[NSOperationQueue alloc] init];
      parserOp = nil;
      feedFilters = nil;
      
      flipRefreshDelayed = NO;
      apnItems = 0;
   }

   return self;
}

//________________________________________________________________________________________
- (void) dealloc
{
   [[NSNotificationCenter defaultCenter] removeObserver : self];
}

#pragma mark - Feed's setters.

//________________________________________________________________________________________
- (void) setFeedURLString : (NSString *) urlString
{
   assert(urlString != nil && "setFeedURLString:, parameter 'urlString' is nil");
   
   feedURLString = urlString;
}

//________________________________________________________________________________________
- (void) setFilters : (NSObject *) filters
{
   assert(filters != nil && "setFilters:, parameter 'filters' is nil");
   
   //At the moment I filter only using strings (invalid urls to exclude).
   assert([filters isKindOfClass : [NSArray class]] && "setFilters:, filters has a wrong type");
   
   feedFilters = (NSArray *)filters;
   //filters[i] must be a string!
}

#pragma mark - Overriders for UIViewController methods.

//________________________________________________________________________________________
- (void) viewDidLoad
{
   [super viewDidLoad];
   
   CernAPP::AddSpinner(self);
   CernAPP::HideSpinner(self);
   
   [self createPages];
   [self addTileTapObserver];
   
   [self.view addSubview : currPage];
   [self.view bringSubviewToFront : currPage];
 /*
   if (CernAPP::SystemVersionGreaterThanOrEqualTo(@"7.0")) {
      //http://stackoverflow.com/questions/18897485/achieving-bright-vivid-colors-for-an-ios-7-translucent-uinavigationbar
      UIView * const backgroundView = [[UIView alloc] initWithFrame : CGRectMake(0, 0, CGRectGetWidth(self.navigationController.navigationBar.frame), 64)];
      backgroundView.backgroundColor = [UIColor colorWithRed : 0.f green : 83.f / 255.f blue : 161.f / 255.f alpha : 0.15f];
      backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
      [self.navigationController.view insertSubview:backgroundView belowSubview:self.navigationController.navigationBar];
   }*/
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
         [self showAPNHints];
         [self layoutFeedViews];
         //
         [self loadVisiblePageData];
         return;//No need to refresh.
      }

      (void)[self initTilesFromDBCache];
      [self layoutPanRegion];
      [self refresh];
   }
   
   [self showAPNHints];
}

#pragma mark - PageController protocol.

//________________________________________________________________________________________
- (void) layoutFeedViews
{
   [self layoutPages : YES];
   [self layoutFlipView];
   [self layoutPanRegion];

   if (nPages > 1) {
      if (!currPage.pageNumber)
         [self showRightFlipHint];
      else if (currPage.pageNumber == nPages - 1)
         [self showLeftFlipHint];
   } else
      [self hideFlipHint];
}

//________________________________________________________________________________________
- (void) refresh
{
   if (parserOp)
      return;

   //Stop any image download if we have any.
   [self cancelAllImageDownloaders];

   if (![self hasConnection] && !dataItems.count) {
      //Network problems, we can not reload
      //and do not have any previous data to show.
      [self setPagesData];
      
      [self layoutPages : NO];//NO - no tiles to layout.
      [self layoutFlipView];
      
      CernAPP::ShowErrorHUD(self, @"No network");

      return;
   }//If we do not have connection, but have articles,
    //the network error will be reported by the feedParser. (TODO: check this!)

   [self.noConnectionHUD hide : YES];

   if (!feedCache) {
      self.navigationItem.rightBarButtonItem.enabled = NO;
      CernAPP::ShowSpinner(self);
   } else {
      [self addNavBarSpinner];//A spinner will replace a button in a navigation bar
      [self layoutFeedViews];
   }

   [self startFeedParser];
}

//________________________________________________________________________________________
- (void) refresh : (id) sender
{
#pragma unused(sender)

   if (parserOp)//assert? can this ever happen?
      return;

   if (![self hasConnection]) {
      CernAPP::ShowErrorAlert(@"Please, check network", @"Close");
      CernAPP::HideSpinner(self);
      [self showAPNHints];
      return;
   }

   [self refresh];
}

#pragma mark - FeedParserOperationDelegate and related methods.

//________________________________________________________________________________________
- (void) startFeedParser
{
   assert(parserOp == nil && "startFeedParser, parsing operation is still active");
   assert(parserQueue != nil && "startFeedParser, operation queue is nil");
   assert(feedURLString != nil && "startFeedParser, feedURLString is nil");

   parserOp = [[FeedParserOperation alloc] initWithFeedURLString : feedURLString];
   parserOp.delegate = self;
   [parserQueue addOperation : parserOp];
}

#pragma mark - FeedParseOperationDelegate

//________________________________________________________________________________________
- (void) parserDidFailWithError : (NSError *) error
{
//In the current version error is ignored.
#pragma unused(error)

   //TODO: test this!
   CernAPP::HideSpinner(self);
   [self hideNavBarSpinner];

   if (self.navigationController.topViewController == self && !flipAnimator.animationLock)
      CernAPP::ShowErrorAlert(@"Please, check network!", @"Close");

   if (!dataItems.count)
      CernAPP::ShowErrorHUD(self, @"No network");//TODO: better error message?
   
   parserOp = nil;
   if (!apnItems)
      self.navigationItem.rightBarButtonItem.enabled = YES;
   else {
      [self showAPNHints];
   }
}

//________________________________________________________________________________________
- (void) parserDidFinishWithInfo : (MWFeedInfo *) info items : (NSArray *) items
{
#pragma unused(info)

   assert(items != nil && "parserDidFinishWithInfo:items:, parameter 'items' is nil");
   
   if (!items.count)
      //Consider this as a network error.
      return [self parserDidFailWithError : nil];
   
   assert(feedCacheID.length && "parserDidFinishWithInfo:items:, feedCacheID is invalid");
   CernAPP::WriteFeedCache(feedCacheID, feedCache, items);

   dataItems = [[NSMutableArray alloc] init];
   for (MWFeedItem *item in items) {
      //Ooops, can be quite expensive :)
      bool filterOut = false;
      for (NSObject *filter in feedFilters) {
         assert([filter isKindOfClass : [NSString class]] &&
                "parserDidFinishWithInfo:items:, filter is expected to be a string");
         const NSRange subRange = [item.link rangeOfString : (NSString *)filter];//filter must be a substring.
         if (subRange.location != NSNotFound) {
            filterOut = true;
            break;
         }
      }
      
      if (!filterOut)
         [dataItems addObject : item];
   }

   if (feedCache)
      feedCache = nil;
   
   [self hideNavBarSpinner];
   CernAPP::HideSpinner(self);
   [self hideAPNHints];
   //Cache data in app delegate.
   [self cacheInAppDelegate];
   //
   parserOp = nil;
   
   if (flipAnimator.animationLock)
      delayedFlipRefresh = YES;
   else {
      delayedFlipRefresh = NO;
      panGesture.enabled = NO;
      [self refreshAfterFlip];
      panGesture.enabled = YES;
   }
}

//________________________________________________________________________________________
- (void) refreshAfterFlip
{
   self.navigationItem.rightBarButtonItem.enabled = YES;

   [self setTilesLayoutHints];
   [self setPagesData];
   
   [self layoutPages : YES];
   [self layoutFlipView];
   
   [self loadVisiblePageData];

   if (nPages > 1)
      [self showRightFlipHint];
   else
      [self hideFlipHint];
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
   if (feedCache || parserOp || !dataItems.count)//Do not start any downloader while refreshing:
      return;                 //by the end of refresh all images will become (possibly) invalid.
   
   if (!downloaders)
      downloaders = [[NSMutableDictionary alloc] init];

   NSNumber * const key = [NSNumber numberWithUnsignedInteger : currPage.pageNumber];
   if (downloaders[key])
      return;
   
   NSMutableArray * const thumbnails = [[NSMutableArray alloc] init];
   const NSRange range = currPage.pageRange;
   
   bool needUpdate = false;
   
   for (NSUInteger i = range.location, e = range.location + range.length; i < e; ++i) {
      MWFeedItem * const article = (MWFeedItem *)dataItems[i];
      if (!article.image) {
         //May be, we already have a downloader for this item?
         NSString * body = article.content;
         if (!body)
            body = article.summary;
         
         NSString *urlString = CernAPP::FindImageURLStringInHTMLString(body);
         if (!urlString)//Now we have some feeds, which contain RSS enclosure with images for entries.
            urlString = CernAPP::FindImageURLStringInEnclosures(article);

         if (urlString) {
            KeyVal * const newThumbnail = [[KeyVal alloc] init];
            newThumbnail.key = [NSIndexPath indexPathForRow : i inSection : currPage.pageNumber];
            newThumbnail.val = CernAPP::Details::GetThumbnailURLString(urlString);
            [thumbnails addObject : newThumbnail];
         }
      } else if (![currPage tileHasThumbnail : i - range.location]) {
         needUpdate = true;
         [currPage setThumbnail : article.image forTile : i - range.location doLayout : NO];
      }
   }

   if (needUpdate) {
      [currPage layoutTiles];
      [flipView replaceCurrentFrame : currPage];
   }
   
   if (thumbnails.count) {
      ThumbnailDownloader * const newDownloader = [[ThumbnailDownloader alloc] initWithItems : thumbnails
                                                   sizeLimit : 500000  downscaleToSize : 200.f];
      [downloaders setObject : newDownloader forKey : key];
      newDownloader.pageNumber = currPage.pageNumber;
      newDownloader.delegate = self;
      [newDownloader startDownload];
   }
}

#pragma mark - PageThumbnailDownloaderDelegate

//________________________________________________________________________________________
- (void) thumbnailsDownloadDidFihish : (ThumbnailDownloader *) thumbnailsDownloader
{
   assert(thumbnailsDownloader != nil &&
          "thumbnailsDownloadDidFinish:, parameter 'thumbnailsDownloader' is nil");
   
   NSMutableDictionary * const imageDownloaders = thumbnailsDownloader.imageDownloaders;
   BOOL currPageUpdated = NO;
   const NSRange currRange = currPage.pageRange;
   
   NSEnumerator * const keyEnumerator = [imageDownloaders keyEnumerator];
   for (id key in keyEnumerator) {
      ImageDownloader * const imageDownloader = (ImageDownloader *)imageDownloaders[key];

      if (imageDownloader.image) {
         NSIndexPath * const path = imageDownloader.indexPathInTableView;
         assert(path != nil &&
                "thumbnailsDownloadDidFinish:, invalid image path");
         const NSInteger pageNumber = path.section;
         assert(pageNumber >= 0 && pageNumber < NSInteger(nPages) &&
                "thumbnailsDownloadDidFinish:, page index is out of bounds");
         
         const NSInteger articleIndex = path.row;
         assert(articleIndex >= 0 && articleIndex < dataItems.count &&
                "thumbnailsDownloadDidFinish:, article index is out of bounds");
         
         MWFeedItem * const article = (MWFeedItem *)dataItems[articleIndex];
         article.image = imageDownloader.image;
         
         if (pageNumber == currPage.pageNumber && ![currPage tileHasThumbnail : articleIndex - currRange.location] && !flipAnimator.animationLock) {
            //
            currPageUpdated = YES;
            //Set the thumbnail but do not resize anything yet.
            [currPage setThumbnail : imageDownloader.image forTile : articleIndex - currRange.location doLayout : NO];
         }
      }
   }
   
   if (thumbnailsDownloader.pageNumber == currPage.pageNumber && !flipAnimator.animationLock) {
      for (NSUInteger i = currRange.location, e = i + currRange.length; i < e; ++i) {
         MWFeedItem * const article = (MWFeedItem *)dataItems[i];
         if (article.image && ![currPage tileHasThumbnail:i - currRange.location]) {
            currPageUpdated = YES;
            [currPage setThumbnail : article.image forTile:i - currRange.location doLayout : NO];
         }
      }
   }
  
   [downloaders removeObjectForKey : [NSNumber numberWithUnsignedInteger : thumbnailsDownloader.pageNumber]];
   
   if (currPageUpdated) {
      panGesture.enabled = NO;
      [currPage layoutTiles];
      [flipView replaceCurrentFrame : currPage];
      panGesture.enabled = YES;
   }
}

#pragma mark - UI

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
                                                target : self action : @selector(refresh:)];
   }
}

#pragma mark - User interactions.

//________________________________________________________________________________________
- (void) articleSelected : (NSNotification *) notification
{
   assert(notification != nil && "articleSelected:, parameter 'notification' is nil");
   assert([notification.object isKindOfClass : [MWFeedItem class]] &&
          "articleSelected:, an object in a notification has a wrong type");
   
   MWFeedItem * const feedItem = (MWFeedItem *)notification.object;
   ArticleDetailViewController * const viewController = [self.storyboard instantiateViewControllerWithIdentifier : CernAPP::ArticleDetailViewControllerID];
   [viewController setContentForArticle : feedItem];
   viewController.navigationItem.title = @"";

   if (feedItem.title && feedCacheID)
      viewController.articleID = [feedCacheID stringByAppendingString : feedItem.title];

   viewController.canUseReadability = !CernAPP::SkipReadabilityProcessing(feedItem.link);
   [self.navigationController pushViewController : viewController animated : YES];
}

//________________________________________________________________________________________
- (void) sendSelectedArticle : (NSNotification *) notification
{
#pragma unused(notification)
}

#pragma mark - ConnectionController protocol.

//________________________________________________________________________________________
- (void) cancelAnyConnections
{
   [parserQueue cancelAllOperations];
   parserOp = nil;
   [self cancelAllImageDownloaders];
}

#pragma mark - Aux. functions.

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

//________________________________________________________________________________________
- (BOOL) initTilesFromDBCache
{
   assert(feedCacheID != nil && "initTilesFromDBCache, invalid feedCacheID");

   if ((feedCache = CernAPP::ReadFeedCache(feedCacheID))) {
      //Set the data from the cache at the beginning!
      dataItems = CernAPP::ConvertFeedCache(feedCache);
      [self setPagesData];
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
   }

   return dataItems != nil;//no ptr to BOOL conversion.
}

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

//________________________________________________________________________________________
- (void) cancelAllImageDownloaders
{
   if (downloaders && downloaders.count) {
      NSEnumerator * const keyEnumerator = [downloaders keyEnumerator];
      for (id key in keyEnumerator) {
         ThumbnailDownloader * const downloader = (ThumbnailDownloader *)downloaders[key];
         [downloader cancelDownload];
      }
      
      downloaders = nil;
   }
}

#pragma mark - APNEnabledController and aux. methods.

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

@end
