//Author: Timur Pocheptsov.
//Developed for CERN app.

#import <cassert>

#import <Availability.h>

#import "ArticleDetailViewController.h"
#import "ECSlidingViewController.h"
#import "NewsTableViewController.h"
#import "StoryboardIdentifiers.h"
#import "MenuViewController.h"
#import "CellBackgroundView.h"
#import "NewsTableViewCell.h"
#import "ApplicationErrors.h"

//TODO: This must be replaced in a future with Detail.h or something like this:
//the file with the "hidden" source code.
#import "TwitterAPI.h"

#import "Reachability.h"
#import "DeviceCheck.h"
#import "APNHintView.h"
#import "AppDelegate.h"
#import "GUIHelpers.h"
#import "URLHelpers.h"
#import "FeedCache.h"
#import "APNUtils.h"
#import "KeyVal.h"

@implementation NewsTableViewController {
   NSMutableArray *allArticles;

   UIActivityIndicatorView *navBarSpinner;
   BOOL firstViewDidAppear;
   
   NSString *feedURLString;
   NSOperationQueue *parseQueue;
   
   Reachability *internetReach;
   
   NSMutableArray *rangeDownloaders;

   NSArray *feedFilters;
}

@synthesize feedCacheID, apnID, apnItems;


#pragma mark - Reachability.

//________________________________________________________________________________________
- (BOOL) hasConnection
{
   assert(internetReach != nil && "hasConnection, internetReach is nil");

   return [internetReach currentReachabilityStatus] != CernAPP::NetworkStatus::notReachable;
}

#pragma mark - Construction/destruction.

//________________________________________________________________________________________
- (void) doInitTableViewController
{
   //ivars from the header (interface declaration).
   feedCache = nil;
   spinner = nil;
   noConnectionHUD = nil;
   parseOp = nil;
   feedCacheID = nil;
   apnID = 0;

   //'private' ivars (hidden in mm file).
   allArticles = nil;

   navBarSpinner = nil;
   firstViewDidAppear = YES;

   feedURLString = nil;
   parseQueue = [[NSOperationQueue alloc] init];

   internetReach = [Reachability reachabilityForInternetConnection];
   
   rangeDownloaders = nil;

   feedFilters = nil;
   apnItems = 0;
}

//________________________________________________________________________________________
- (id) initWithNibName : (NSString *) nibNameOrNil bundle : (NSBundle *) nibBundleOrNil
{
   if (self = [super initWithNibName : nibNameOrNil bundle : nibBundleOrNil])
      [self doInitTableViewController];

   return self;
}


//________________________________________________________________________________________
- (id) initWithCoder : (NSCoder *) aDecoder
{
   if (self = [super initWithCoder : aDecoder])
      [self doInitTableViewController];

   return self;
}

//________________________________________________________________________________________
- (id) initWithStyle : (UITableViewStyle) style
{
   if (self = [super initWithStyle : style])
      [self doInitTableViewController];

   return self;
}

#pragma mark - Setters.

//________________________________________________________________________________________
- (void) setFeedURLString : (NSString *) urlString
{
   assert(urlString != nil && "setFeedURLString:, parameter 'urlString' is nil");
   
   feedURLString = urlString;
}

//________________________________________________________________________________________
- (void) setFilters : (NSObject *) filters
{
   //We work only with 'invalid url substrings' as filters at the moment.
   //filters is an NSArray of NSStrings.
   
   assert(filters != nil && "setFilters:, parameter 'filters' is nil");
   assert([filters isKindOfClass : [NSArray class]] &&
          "setFilters:, filters has a wrong type");
   
   feedFilters = (NSArray *)filters;
}

#pragma mark - viewDid/Will/Should/Must/Could/Would stuff.

//________________________________________________________________________________________
- (void) viewDidLoad
{
   //This method is called once somewhere at the beginning,
   //we do some additional setup here.

   [super viewDidLoad];

   self.tableView.showsHorizontalScrollIndicator = NO;
   self.tableView.showsVerticalScrollIndicator = NO;
   
   //Allocate/initialize UIActivityIndicatorView to show at the center of a tableview:
   //only the first time the table is loading (and if we do not have cache -
   //in this case activity indicator will be in a navigation bar).

   using CernAPP::spinnerSize;
   const CGPoint spinnerOrigin = CGPointMake(self.view.frame.size.width / 2 - spinnerSize / 2, self.view.frame.size.height / 2 - spinnerSize / 2);
   spinner = [[UIActivityIndicatorView alloc] initWithFrame : CGRectMake(spinnerOrigin.x, spinnerOrigin.y, spinnerSize, spinnerSize)];
   spinner.color = [UIColor grayColor];
   [self.view addSubview : spinner];
   [spinner setHidden : YES];

   //Nice refresh control at the top of a table-view (this shit kills application
   //if combined with empty footer view, which is a standard trick to hide empty rows).
   self.refreshControl = [[UIRefreshControl alloc] init];
   [self.refreshControl addTarget : self action : @selector(reloadFromRefreshControl) forControlEvents : UIControlEventValueChanged];
   
   //
   [self.tableView registerClass : [NewsTableViewCell class] forCellReuseIdentifier : [NewsTableViewCell cellReuseIdentifier]];
}

//________________________________________________________________________________________
- (BOOL) initFromAppCache
{
   //Read feed's contents from the app's cache, if any.

   assert(feedCacheID != nil && "initFromAppCache, feedCacheID is nil");

   assert([[UIApplication sharedApplication].delegate isKindOfClass : [AppDelegate class]] &&
          "initFromAppCache, app delegate has a wrong type");
   
   AppDelegate * const appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
   if (NSObject * const cache = [appDelegate cacheForKey : feedCacheID]) {
      assert([cache isKindOfClass : [NSMutableArray class]] &&
             "initFromAppCache, cached object has a wrong type");
      allArticles = (NSMutableArray *)cache;
      return YES;
   }

   return NO;
}

//________________________________________________________________________________________
- (BOOL) initFromDBCache
{
   //Read feed's contents from DB, if any.

   assert(feedCacheID != nil && "initFromDBCache, feedCacheID is nil");
   
   if ((feedCache = CernAPP::ReadFeedCache(feedCacheID))) {
      //Convert persistent objects into feed items.
      allArticles = CernAPP::ConvertFeedCache(feedCache);
      return YES;
   }
   
   return NO;
}

//________________________________________________________________________________________
- (void) addContentsToAppCache
{
   //Save a feed's data into the app delegate.

   assert(feedCacheID != nil && "addContentsToAppCache, feedStoreID is nil");

   if (allArticles && allArticles.count) {
      assert([[UIApplication sharedApplication].delegate isKindOfClass : [AppDelegate class]] &&
             "addContentsToAppCache, app delegate has a wrong type");
      
      AppDelegate * const appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
      [appDelegate cacheData : allArticles withKey : feedCacheID];
   }
}

//________________________________________________________________________________________
- (void) viewDidAppear : (BOOL)animated
{
   [super viewDidAppear : animated];

   //viewDidAppear can be called many times: the first time when controller
   //created and view loaded, next time - for example, when article detailed view
   //controller is poped from the navigation stack.

   if (CernAPP::SystemVersionGreaterThanOrEqualTo(@"7.0")) {
#ifdef __IPHONE_7_0
      [self.slidingViewController.panGesture requireGestureRecognizerToFail:self.tableView.panGestureRecognizer];
#endif
      if (CernAPP::SystemVersionGreaterThanOrEqualTo(@"7.0"))
         [self.slidingViewController.panGesture requireGestureRecognizerToFail:self.tableView.panGestureRecognizer];
   }

   if (firstViewDidAppear) {
      firstViewDidAppear = NO;
      
      //We can have two "types of cache":
      //if we're loading some feed the first time,
      //it's possible we have some data in the database for
      //the given feedStoreID. So while the feed if being refreshed,
      //we can already show something. Another case - if we are reading
      //the same feed twice (selecting the same menu item) - there is no
      //need to re-download/re-parse/re-download thumbnails, we can
      //use the previous data and refresh only on demand.
      assert(feedCacheID != nil && "viewDidAppear:, feedCacheID is nil");

      if ([self initFromAppCache]) {
         [self.tableView reloadData];//Load table with cached data, if any.
         [self showAPNHints];
         //No need to refresh unless user asks about it.
         return;
      }
      
      (void)[self initFromDBCache];
      [self.tableView reloadData];//Load table with cached data, if any.
      [self reload];      
   }
   
   [self showAPNHints];
}

//________________________________________________________________________________________
- (void) viewWillAppear : (BOOL) animated
{
   [super viewWillAppear : animated];
   
   //UITableView shows empty rows, though I did not ask it to do this.
   self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
}

#pragma mark - Reload/refresh logic.

//________________________________________________________________________________________
- (void) reloadFromRefreshControl
{
   if (parseOp) {
      //Do not try to reload if aggregator is still working.
      [self.refreshControl endRefreshing];
      return;
   }

   if (![self hasConnection]) {
      CernAPP::ShowErrorAlert(@"Please, check network", @"Close");
      [self.refreshControl endRefreshing];
      [self hideActivityIndicators];
      [self showAPNHints];
      return;
   }

   [self reloadShowHUD : NO];
}

//________________________________________________________________________________________
- (void) reload
{
   if (parseOp)
      return;

   [self reloadShowHUD : YES];
}

//________________________________________________________________________________________
- (void) reloadShowHUD : (BOOL) show
{
   //This function is called either the first time we are loading table
   //(if we have a cache, we show spinner in a nav-bar, if no - in the center),
   //and it can be also called after 'pull-refresh', in this case, we do not show
   //spinner (it's done by refreshControl).

   if (parseOp)
      return;

   //Stop an image download if we have any.
   [self cancelAllImageDownloaders];

   if (![self hasConnection]) {
      //Network problems, we can not reload
      //and do not have any previous data to show.
      if (!feedCache && !allArticles.count) {
         [self showErrorHUD];
         return;
      }
   }

   [noConnectionHUD hide : YES];
   
   if (show) {
      //HUD: either spinner in the center
      //or spinner in a navigation bar.
      if (!feedCache) {
         [spinner setHidden : NO];
         [spinner startAnimating];
      } else {
         [self addNavBarSpinner];
      }
   }

   [self startFeedParsing];
}

#pragma mark - FeedParseOperationDelegate and related methods.

//________________________________________________________________________________________
- (void) startFeedParsing
{
   assert(parseOp == nil && "startFeedParsing, called while the previous operation is still active");
   assert(parseQueue != nil && "startFeedParsing, operation queue is nil");
   assert(feedURLString != nil && "startFeedParsing, feedURLString is nil");
   
   parseOp = [[FeedParserOperation alloc] initWithFeedURLString : feedURLString];
   parseOp.delegate = self;
   [parseQueue addOperation : parseOp];
}

//________________________________________________________________________________________
- (void) parserDidFinishWithInfo : (MWFeedInfo *) info items : (NSArray *) items
{
#pragma unused(info)

   assert(items != nil && "parserDidFinishWithInfo:items:, parameter 'items' is nil");
   assert(feedCacheID != nil && "parserDidFinishWithInfo:items:, feedCacheID is nil, can not write a DB cache");
   
   if (!items.count)
      return [self parserDidFailWithError : nil];

   CernAPP::WriteFeedCache(feedCacheID, feedCache, items);

   allArticles = [[NSMutableArray alloc] init];
   for (MWFeedItem *item in items) {
      //Hehehe :(
      bool filterOut = false;
      for (NSObject *filter in feedFilters) {
         assert([filter isKindOfClass : [NSString class]] && "filter object has a wrong type");
         const NSRange filterRange = [item.link rangeOfString : (NSString *)filter];
         if (filterRange.location != NSNotFound) {
            filterOut = true;
            break;
         }
      }
      
      if (!filterOut)
         [allArticles addObject : item];
   }

   [self addContentsToAppCache];

   feedCache = nil;

   [self hideActivityIndicators];

   parseOp = nil;

   [self.refreshControl endRefreshing];//well, if we have it active.
   [self.tableView reloadData];//we have new articles, now we can reload the table.
   [self loadImagesForOnscreenRows];
   
   [self hideAPNHints];
}

//________________________________________________________________________________________
- (void) parserDidFailWithError : (NSError *) error
{
//Error is ignored in the current version.
#pragma unused(error)
   [self hideActivityIndicators];

   parseOp = nil;

   if (allArticles.count) {
      //We have either cache, or articles from the previous parse.
      //Do not use HUD (which hides the table's contents), just
      //show an alert (only if 'self' is the current top view controller!)
      if (self.navigationController.topViewController == self)
         CernAPP::ShowErrorAlert(@"Please, check network connection", @"Close");
   } else {
      [self showErrorHUD];
   }
   
   [self showAPNHints];
}

#pragma mark - UITableViewDataSource.

//________________________________________________________________________________________
- (NSInteger) numberOfSectionsInTableView : (UITableView *) tableView
{
#pragma unused(tableView)
   //Table has only one section.
   return 1;
}

//________________________________________________________________________________________
- (NSInteger) tableView : (UITableView *) tableView numberOfRowsInSection : (NSInteger) section
{
#pragma unused(tableView, section)
   return allArticles.count;
}

//________________________________________________________________________________________
- (UITableViewCell *) tableView : (UITableView *) tableView cellForRowAtIndexPath : (NSIndexPath *) indexPath
{
#pragma unused(tableView)

   assert(indexPath != nil && "tableView:cellForRowAtIndexPath:, parameter 'indexPath' is nil");

   UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier : [NewsTableViewCell cellReuseIdentifier]];
   assert((!cell || [cell isKindOfClass : [NewsTableViewCell class]]) &&
          "tableView:cellForRowAtIndexPath, reusable cell has a wrong type");
   
   if (!cell)
      cell = [[NewsTableViewCell alloc] initWithFrame : [NewsTableViewCell defaultCellFrame]];

   if (![cell.selectedBackgroundView isKindOfClass : [CellBackgroundView class]])
      cell.backgroundView = [[CellBackgroundView alloc] initWithFrame : CGRect()];

   const NSInteger row = indexPath.row;
   assert(row >= 0 && row < allArticles.count && "tableView:cellForRowAtIndexPath:, row is out of bounds");

   MWFeedItem * const article = (MWFeedItem *)allArticles[row];
   [(NewsTableViewCell *)cell setCellData : article imageOnTheRight : (indexPath.row % 4) == 3];

   return cell;
}

//________________________________________________________________________________________
- (CGFloat) tableView : (UITableView *) tableView heightForRowAtIndexPath : (NSIndexPath *) indexPath
{
#pragma unused(tableView)

   assert(indexPath != nil && "tableView:heightForRowAtIndexPath:, parameter 'indexPath' is nil");

   const NSInteger row = indexPath.row;
   assert(row >= 0 && row < allArticles.count && "tableView:heightForRowAtIndexPath:, indexPath.row is out of bounds");

   MWFeedItem * const article = (MWFeedItem *)allArticles[row];
   return [NewsTableViewCell calculateCellHeightForData : article imageOnTheRight : (indexPath.row % 4) == 3];
}

#pragma mark - Table view delegate

//________________________________________________________________________________________
- (void) tableView : (UITableView *) tableView didSelectRowAtIndexPath : (NSIndexPath *) indexPath
{
#pragma unused(tableView)

   assert(indexPath != nil && "tableView:didSelectRowAtIndexPath, index path for selected table's row is nil");

   //Yes, it's possible to tap a table cell many times (while table is still reloading), this
   //leads to the navigation stack corruption :(((
   if (self.navigationController.topViewController != self)
      return;

   const NSUInteger row = indexPath.row;
   if (row >= allArticles.count)//Ooops, cell was tapped while refreshing???
      return;

   MWFeedItem * const feedItem = (MWFeedItem *)allArticles[row];

   UIStoryboard * const mainStoryboard = [UIStoryboard storyboardWithName :
                                          CernAPP::SystemVersionGreaterThanOrEqualTo(@"7.0") ? @"iPhone_iOS7" : @"iPhone"
                                          bundle : nil];
   ArticleDetailViewController * const viewController = [mainStoryboard instantiateViewControllerWithIdentifier : CernAPP::ArticleDetailViewControllerID];
   [viewController setContentForArticle : feedItem];
   viewController.navigationItem.title = @"";

   if (feedItem.title && feedCacheID)
      viewController.articleID = [feedCacheID stringByAppendingString : feedItem.title];

   viewController.canUseReadability = !CernAPP::SkipReadabilityProcessing(feedItem.link);
   [self.navigationController pushViewController : viewController animated : YES];

   [tableView deselectRowAtIndexPath : indexPath animated : NO];
}

#pragma mark - Sliding view controller's "menu"

//________________________________________________________________________________________
- (IBAction) revealMenu : (id) sender
{
#pragma unused(sender)
   [self.slidingViewController anchorTopViewTo : ECRight];
}

#pragma mark - Connection controller.

//________________________________________________________________________________________
- (void) cancelAnyConnections
{
   [parseQueue cancelAllOperations];
   parseOp = nil;
   [self cancelAllImageDownloaders];
}

//________________________________________________________________________________________
- (void) cancelAllImageDownloaders
{
   for (ThumbnailDownloader *downloader in rangeDownloaders)
      [downloader cancelDownload];

   rangeDownloaders = nil;
}

#pragma mark - UIScrollView delegate.

// Load images for all onscreen rows (if not done yet) when scrolling is finished
//________________________________________________________________________________________
- (void) scrollViewDidEndDragging : (UIScrollView *) scrollView willDecelerate : (BOOL) decelerate
{
#pragma unused(scrollView)

   //Cached feeds do not have any images.
   if (!feedCache && !parseOp) {
      if (!decelerate)
         [self loadImagesForOnscreenRows];
   }
}

//________________________________________________________________________________________
- (void) scrollViewDidEndDecelerating : (UIScrollView *) scrollView
{
#pragma unused(scrollView)

   //No images in a cached feed.
   if (!feedCache && !parseOp)
      [self loadImagesForOnscreenRows];
}

#pragma mark - Download images for news' items in a table.

//________________________________________________________________________________________
- (BOOL) hasDownloaderForIndexPath : (NSIndexPath *) indexPath
{
   assert(indexPath != nil && "hasDownloaderForIndexPath:, parameter 'indexPath' is nil");
   assert(rangeDownloaders != nil && "hasDownloaderForIndexPath:, rangeDownloaders is nil");
   
   for (ThumbnailDownloader *downloader in rangeDownloaders) {
      if ([downloader containsIndexPath : indexPath])
         return YES;
   }
   
   return NO;
}

//________________________________________________________________________________________
- (void) loadImagesForOnscreenRows
{
   assert(feedCache == nil && "loadImagesForOnscreenRows, controller is in a wrong mode");

   if (allArticles.count) {
      if (!rangeDownloaders)
         rangeDownloaders = [[NSMutableArray alloc] init];
   
      NSMutableArray * const pairs = [[NSMutableArray alloc] init];
      NSArray * const visiblePaths = [self.tableView indexPathsForVisibleRows];
      for (NSIndexPath *indexPath in visiblePaths) {
         MWFeedItem * const article = allArticles[indexPath.row];
         if (!article.image && ![self hasDownloaderForIndexPath : indexPath]) {
            NSString * body = article.content;
            if (!body)
               body = article.summary;
         
            NSString *urlString = CernAPP::FindUnescapedImageURLStringInHTMLString(body);
            if (!urlString)
               urlString = CernAPP::FindImageURLStringInEnclosures(article);
         
            if (urlString) {
               KeyVal * const newThumbnail = [[KeyVal alloc] init];
               newThumbnail.key = indexPath;
               newThumbnail.val = CernAPP::Details::GetThumbnailURLString(urlString);
               [pairs addObject : newThumbnail];
            }
         }
      }
         
      if (pairs.count) {
         ThumbnailDownloader * const pageDownloader = [[ThumbnailDownloader alloc] initWithItems : pairs
                                                       sizeLimit : 500000 downscaleToSize : 150.f];
         [rangeDownloaders addObject : pageDownloader];
         pageDownloader.delegate = self;
         [pageDownloader startDownload];
      }
   }
}

#pragma mark - PageThumbnailDownloader delegate.

//________________________________________________________________________________________
- (void) thumbnailsDownloadDidFihish : (ThumbnailDownloader *) downloader
{
   assert(downloader != nil && "thumbnailsDownloadDidFinish:, parameter 'downloader' is nil");
   assert(rangeDownloaders != nil && "thumbnailsDownloadDidFinish:, rangeDownloaders is nil");
   assert([rangeDownloaders containsObject : downloader] == YES &&
          "thumbnailsDownloadDidFinish:, downloader not found");
   //
   NSMutableArray * const rowsToUpdate = [[NSMutableArray alloc] init];
   NSMutableDictionary * const downloaders = downloader.imageDownloaders;
   
   NSEnumerator * const keyEnumerator = [downloaders keyEnumerator];
   for (id key in keyEnumerator) {
      ImageDownloader * const imageDownloader = (ImageDownloader *)downloaders[key];

      if (imageDownloader.image) {
         NSIndexPath * const path = imageDownloader.indexPathInTableView;
         assert(path != nil &&
                "thumbnailsDownloadDidFinish:, invalid image path");
         const NSInteger articleIndex = path.row;
         assert(articleIndex >= 0 && articleIndex < allArticles.count &&
                "thumbnailsDownloadDidFinish:, article index is out of bounds");
         
         MWFeedItem * const article = (MWFeedItem *)allArticles[articleIndex];
         article.image = imageDownloader.image;
         
         [rowsToUpdate addObject : [NSIndexPath indexPathForRow:articleIndex inSection : 0]];
      }
   }
   
   [rangeDownloaders removeObject : downloader];

   if (rowsToUpdate.count)
      [self.tableView reloadRowsAtIndexPaths : rowsToUpdate withRowAnimation : UITableViewRowAnimationNone];
}

#pragma mark - Interface rotation.

//________________________________________________________________________________________
- (BOOL) shouldAutorotate
{
   //We never rotate news table view.
   return NO;
}

#pragma mark - GUI

//________________________________________________________________________________________
- (void) hideActivityIndicators
{
   if (spinner.isAnimating)
      [spinner stopAnimating];
   
   if (!spinner.isHidden)
      [spinner setHidden : YES];

   [self.refreshControl  endRefreshing];
   [self hideNavBarSpinner];
}

//________________________________________________________________________________________
- (void) addNavBarSpinner
{
   navBarSpinner = [[UIActivityIndicatorView alloc] initWithFrame : CGRectMake(0.f, 0.f, 20.f, 20.f)];
   UIBarButtonItem * const barButton = [[UIBarButtonItem alloc] initWithCustomView : navBarSpinner];
   // Set to Left or Right
   self.navigationItem.rightBarButtonItem = barButton;
   [navBarSpinner startAnimating];
}

//________________________________________________________________________________________
- (void) hideNavBarSpinner
{
   [navBarSpinner stopAnimating];
   self.navigationItem.rightBarButtonItem = nil;
}

//________________________________________________________________________________________
- (void) showErrorHUD
{
   [MBProgressHUD hideAllHUDsForView : self.view animated : NO];
   noConnectionHUD = [MBProgressHUD showHUDAddedTo : self.view animated : NO];
   noConnectionHUD.color = [UIColor redColor];
   noConnectionHUD.mode = MBProgressHUDModeText;
   noConnectionHUD.labelText = @"Network error, pull to refresh";
   noConnectionHUD.removeFromSuperViewOnHide = YES;
}

#pragma mark - APN.

//________________________________________________________________________________________
- (void) setApnItems : (NSUInteger) nItems
{
   if (nItems) {
      apnItems = nItems;
      if (!firstViewDidAppear)
         [self showAPNHints];
   } else if (!firstViewDidAppear)
      [self hideAPNHints];
   else
      apnItems = 0;
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
   
   if ([self.navigationItem.rightBarButtonItem.customView isKindOfClass : [APNHintView class]])
      self.navigationItem.rightBarButtonItem = nil;
}

//________________________________________________________________________________________
- (BOOL) containsArticleForAPNHash : (NSString *) apnHash
{
   assert(apnHash != nil && "containsArticleForAPNHash:, parameter 'apnHash' is nil");
   assert(apnHash.length == CernAPP::apnHashSize && "containsArticleForAPNHash:, invalid sha1 hash");
   
   //I have two FindItem, make more obvious, which one is called - do an explicit cast.
   return CernAPP::FindItem(apnHash, (NSObject *)allArticles);
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
         if ([self containsArticleForAPNHash : apnHash]) {
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
   }
}

//________________________________________________________________________________________
- (void) hintTapped
{
   if (parseOp)//We already updating the feed.
      return;

   //Stop an image download if we have any.
   [self cancelAllImageDownloaders];

   if (![self hasConnection]) {
      CernAPP::ShowErrorAlert(@"Please, check network", @"Close");
      return;
   }

   [noConnectionHUD hide : YES];
   
   [self addNavBarSpinner];
   [self startFeedParsing];
}

@end
