//
//  NewsFeedViewController.m
//  CERN
//
//  Created by Timur Pocheptsov on 4/17/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <cstdlib>

#import "ArticleDetailViewController.h"
#import "NewsTableViewController.h"
#import "NewsFeedViewController.h"
#import "StoryboardIdentifiers.h"
#import "ApplicationErrors.h"
#import "FeedItemTileView.h"
#import "FeedPageView.h"
#import "MWFeedItem.h"
#import "FeedCache.h"
#import "FlipView.h"
#import "KeyVal.h"

@implementation NewsFeedViewController {
   BOOL viewDidAppear;

   UIActivityIndicatorView *navBarSpinner;
}

@synthesize aggregator, feedStoreID, noConnectionHUD, spinner;

#pragma mark - Life cycle.

//________________________________________________________________________________________
- (void) doInitController
{
   downloaders = nil;
   viewDidAppear = NO;
   
   aggregator = [[RSSAggregator alloc] init];
   aggregator.delegate = self;
   
   feedCache = nil;
}

//________________________________________________________________________________________
- (id) initWithCoder : (NSCoder *) aDecoder
{
   if (self = [super initWithCoder : aDecoder])
      [self doInitController];

   return self;
}

//________________________________________________________________________________________
- (void) dealloc
{
   [[NSNotificationCenter defaultCenter] removeObserver : self];
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

      [self initTilesFromCache];
      [self layoutPanRegion];
      [self reloadPage];
   }
}

#pragma mark - PageController protocol.

//________________________________________________________________________________________
- (void) reloadPage
{
   if (aggregator.isLoadingData)
      return;

   //Stop any image download if we have any.
   [self cancelAllImageDownloaders];

   if (!aggregator.hasConnection && !dataItems.count) {
      //Network problems, we can not reload
      //and do not have any previous data to show.
      CernAPP::ShowErrorHUD(self, @"No network");
      return;
   }//If we do not have connection, but have articles,
    //the network error will be reported by the RSS aggregator. (TODO: check this!)

   [noConnectionHUD hide : YES];

   if (!feedCache) {
      self.navigationItem.rightBarButtonItem.enabled = NO;
      CernAPP::ShowSpinner(self);
   } else {
      [self addNavBarSpinner];//A spinner will replace a button in a navigation bar
      [self layoutPages : YES];
      [self layoutFlipView];
      [self layoutPanRegion];
   }

   [self.aggregator clearAllFeeds];
   //It will re-parse feed and (probably) re-fill the tiled view.
   [self.aggregator refreshAllFeeds];
}

//________________________________________________________________________________________
- (void) reloadPageFromRefreshControl
{
   if (aggregator.isLoadingData)//assert? can this ever happen?
      return;

   if (!aggregator.hasConnection) {
      CernAPP::ShowErrorAlert(@"Please, check network", @"Close");
      CernAPP::HideSpinner(self);
      return;
   }

   [self reloadPage];
}

#pragma mark - RSSAggregatorDelegate.

//________________________________________________________________________________________
- (void) allFeedsDidLoadForAggregator : (RSSAggregator *) anAggregator
{
#pragma unused(anAggregator)
   //In this mode we always write a cache into the storage.
   assert(feedStoreID.length && "allFeedDidLoadForAggregator:, feedStoreID is invalid");
   CernAPP::WriteFeedCache(feedStoreID, feedCache, aggregator.allArticles);

   dataItems = [aggregator.allArticles mutableCopy];

   if (feedCache) {
      feedCache = nil;
      //We were using cache and had a spinner in a nav bar (while loading a new data).
      [self hideNavBarSpinner];
   } else
      CernAPP::HideSpinner(self);
   
   self.navigationItem.rightBarButtonItem.enabled = YES;

   [self setTilesLayoutHints];
   [self setPagesData];
   
   [self layoutPages : YES];
   [self layoutFlipView];
   
   [self loadVisiblePageData];
}

//________________________________________________________________________________________
- (void) aggregator : (RSSAggregator *) anAggregator didFailWithError : (NSString *) errorDescription
{
   //TODO: test this!
   [self lostConnection : anAggregator];
}

//________________________________________________________________________________________
- (void) lostConnection : (RSSAggregator *) anAggregator
{
#pragma unused(anAggregator)
   //TODO: test this!
   CernAPP::HideSpinner(self);
   [self hideNavBarSpinner];
   
   CernAPP::ShowErrorAlert(@"Please, check network!", @"Close");

   if (!dataItems.count)
      CernAPP::ShowErrorHUD(self, @"No network");//TODO: better error message?

}

#pragma mark - Overriders for TileViewController's methods.

//________________________________________________________________________________________
- (void) loadVisiblePageData
{
   if (feedCache)//We do not load images for a cached feed, since right now we are refreshing the feed.
      return;

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
   }
}

#pragma mark - PageThumbnailDownloaderDelegate

//________________________________________________________________________________________
- (void) thumbnailsDownloadDidFihish : (PageThumbnailDownloader *) thumbnailsDownloader
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
            currPageUpdated = true;
            [currPage setThumbnail : article.image forTile:i - currRange.location doLayout : NO];
         }
      }
   }
   
   [downloaders removeObjectForKey : [NSNumber numberWithUnsignedInteger : thumbnailsDownloader.pageNumber]];
   
   if (currPageUpdated) {
      [currPage layoutTiles];
      [flipView replaceCurrentFrame : currPage];
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
                                                target : self action : @selector(reloadPageFromRefreshControl)];
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

   if (feedItem.title && feedStoreID)
      viewController.articleID = [feedStoreID stringByAppendingString : feedItem.title];

   viewController.canUseReadability = YES;
   [self.navigationController pushViewController : viewController animated : YES];
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
- (void) initTilesFromCache
{
   assert(feedStoreID != nil && "initCache, invalid feedStoreID");

   if ((feedCache = CernAPP::ReadFeedCache(feedStoreID))) {
      //Set the data from the cache at the beginning!
      dataItems = CernAPP::ConvertFeedCache(feedCache);
      [self setPagesData];
   }
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
         PageThumbnailDownloader * const downloader = (PageThumbnailDownloader *)downloaders[key];
         [downloader cancelDownload];
      }
      
      downloaders = nil;
   }
}

@end
