//Author: Timur Pocheptsov.
//Developed for CERN app.


#import <cassert>

#import "ArticleDetailViewController.h"
#import "ECSlidingViewController.h"
#import "NewsTableViewController.h"
#import "StoryboardIdentifiers.h"
#import "CellBackgroundView.h"
#import "NewsTableViewCell.h"
#import "ApplicationErrors.h"
#import "AppDelegate.h"
#import "GUIHelpers.h"
#import "FeedCache.h"

@implementation NewsTableViewController {
   NSMutableArray *allArticles;
   
   NSArray *feedCache;
   BOOL usingCache;
   
   UIActivityIndicatorView *navBarSpinner;
   BOOL firstViewDidAppear;
}

@synthesize aggregator, imageDownloaders, nLoadedImages, feedStoreID, isTwitterFeed;

#pragma mark - Construction/destruction.

//________________________________________________________________________________________
- (void) doInitTableViewController
{
   //Data in Obj-C's object is zero-filled,
   //but still I prefer explicit initialization here
   //(and some ivars/props are not 0).

   allArticles = nil;
   feedCache = nil;
   usingCache = NO;
   navBarSpinner = nil;
   firstViewDidAppear = YES;
   
   canUseCache = YES;

   aggregator = [[RSSAggregator alloc] init];
   aggregator.delegate = self;

   imageDownloaders = nil;
   nLoadedImages = 0;
   isTwitterFeed = NO;
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
   //only the first time the table is loading (and if we do not have our feed in cache -
   //in this case activity indicator will be in a navigation bar).

   using CernAPP::spinnerSize;
   const CGPoint spinnerOrigin = CGPointMake(self.view.frame.size.width / 2 - spinnerSize / 2, self.view.frame.size.height / 2 - spinnerSize / 2);
   spinner = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(spinnerOrigin.x, spinnerOrigin.y, spinnerSize, spinnerSize)];
   spinner.color = [UIColor grayColor];
   [self.view addSubview : spinner];
   [spinner setHidden : YES];
   
   //Nice refresh control at the top of a table-view (this shit kills application
   //if combined with empty footer view, which is a standard trick to hide empty rows).
   self.refreshControl = [[UIRefreshControl alloc] init];
   [self.refreshControl addTarget : self action : @selector(reloadPageFromRefreshControl) forControlEvents : UIControlEventValueChanged];
}

//________________________________________________________________________________________
- (void) viewDidAppear : (BOOL)animated
{
   [super viewDidAppear : animated];

   //viewDidAppear can be called many times: the first time when controller
   //created and view loaded, next time - for example, when article detailed view
   //controller is poped from the navigation stack.

   if (firstViewDidAppear) {
      firstViewDidAppear = NO;
      //read a cache?
      if (canUseCache && feedStoreID) {
         feedCache = CernAPP::ReadFeedCache(feedStoreID);
         usingCache = feedCache != nil;
      }
      //May be, we have a cache already.
      [self.tableView reloadData];
      [self reloadPage];
   }
}

//________________________________________________________________________________________
- (void) viewWillAppear : (BOOL) animated
{
   [super viewWillAppear : animated];
   
   //UITableView shows empty rows, though I did not ask it to do this.
   self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
}

//________________________________________________________________________________________
- (void) didReceiveMemoryWarning
{
   [super didReceiveMemoryWarning];
   // Dispose of any resources that can be recreated.
   //TODO: memory warning??? Try to release images?
   //Remove the controller at all? What else?
}

#pragma mark - Aux. methods to work with aggregators/articles.

//________________________________________________________________________________________
- (void) copyArticlesFromAggregator
{
   assert(aggregator != nil && "copyArticlesFromAggregator, aggregator is nil");

   allArticles = [aggregator.allArticles mutableCopy];
}

//________________________________________________________________________________________
- (void) setAggregator : (RSSAggregator *) rssAggregator
{
   assert(aggregator != nil && "setAggregator:, parameter 'rssAggregator' is nil");

   aggregator = rssAggregator;
   aggregator.delegate = self;
   [self copyArticlesFromAggregator];
}

//________________________________________________________________________________________
- (void) reloadPageFromRefreshControl
{
   if (aggregator.isLoadingData) {
      //Do not try to reload if aggregator is still working.
      [self.refreshControl endRefreshing];
      return;
   }

   if (!aggregator.hasConnection) {
      CernAPP::ShowErrorAlert(@"Please, check network", @"Close");
      [self.refreshControl endRefreshing];
      [self hideActivityIndicators];
      return;
   }

   [self reloadPageShowHUD : NO];
}

//________________________________________________________________________________________
- (void) reloadPage
{
   if (aggregator.isLoadingData)
      return;

   [self reloadPageShowHUD : YES];
}

//________________________________________________________________________________________
- (void) reloadPageShowHUD : (BOOL) show
{
   //This function is called either the first time we are loading table
   //(if we have a cache, we show spinner in a nav-bar, if no - in the center),
   //and it can be also called after 'pull-refresh', in this case, we do not show
   //spinner (it's done by refreshControl).

   if (aggregator.isLoadingData)
      return;
   
   //Stop any image download if we have any.
   [self cancelAllImageDownloaders];

   if (!aggregator.hasConnection) {
      //Network problems, we can not reload
      //and do not have any previous data to show.
      if (!usingCache && !allArticles.count) {
         [self showErrorHUD];
         return;
      }
   }

   [noConnectionHUD hide : YES];
   
   if (show) {
      //HUD: either spinner in the center
      //or spinner in a navigation bar.
      if (!usingCache) {
         [spinner setHidden : NO];
         [spinner startAnimating];
      } else {
         [self addNavBarSpinner];
      }
   }

   [self.aggregator clearAllFeeds];
   
   //Before I was reloading the table, now, I do not touch
   //allArticles/tableView - they are valid until our feed
   //is re-parsed.
   
   //It will re-parse feed and (probably) re-fill the table view.
   [self.aggregator refreshAllFeeds];
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
   // Return the number of rows in the section.
   if (usingCache)
      return feedCache.count;
   else
      return allArticles.count;
}

//________________________________________________________________________________________
- (UITableViewCell *) tableView : (UITableView *) tableView cellForRowAtIndexPath : (NSIndexPath *) indexPath
{
#pragma unused(tableView)

   assert(indexPath != nil && "tableView:cellForRowAtIndexPath:, parameter 'indexPath' is nil");

   NewsTableViewCell *cell = (NewsTableViewCell *)[tableView dequeueReusableCellWithIdentifier : @"NewsCell"];
   if (!cell)
      cell = [[NewsTableViewCell alloc] initWithFrame : [NewsTableViewCell defaultCellFrame]];
   if (![cell.selectedBackgroundView isKindOfClass : [CellBackgroundView class]])
      cell.backgroundView = [[CellBackgroundView alloc] initWithFrame : CGRect()];

   const NSInteger row = indexPath.row;

   if (usingCache) {
      assert(row >= 0 && row < feedCache.count);

      NSManagedObject * const feedItem = (NSManagedObject *)feedCache[row];
      [cell setCellData : [feedItem valueForKey : @"itemTitle"] source : [feedItem valueForKey : @"itemLink"]
                          image : nil imageOnTheRight : NO date : (NSDate *)[feedItem valueForKey : @"itemDate"]];
   } else {
      assert(row >= 0 && row < allArticles.count);

      MWFeedItem * const article = (MWFeedItem *)allArticles[row];
      assert(article != nil && "tableView:cellForRowAtIndexPath:, article was not found");

      [cell setCellData : article imageOnTheRight : (indexPath.row % 4) == 3];

      if (!article.image)
         [self startIconDownloadForIndexPath : indexPath];
   }

   return cell;
}

//________________________________________________________________________________________
- (CGFloat) tableView : (UITableView *) tableView heightForRowAtIndexPath : (NSIndexPath *) indexPath
{
#pragma unused(tableView)

   assert(indexPath != nil && "tableView:heightForRowAtIndexPath:, parameter 'indexPath' is nil");

   const NSInteger row = indexPath.row;

   if (usingCache) {
      assert(row >= 0 && row < feedCache.count && "tableView:heightForRowAtIndexPath:, indexPath.row is out of bounds");

      NSManagedObject * const feedItem = (NSManagedObject *)feedCache[row];
      return [NewsTableViewCell calculateCellHeightForText : [feedItem valueForKey : @"itemTitle"]
                                source : [feedItem valueForKey : @"itemLink"]
                                image : nil
                                imageOnTheRight : NO];
   } else {
      assert(row >= 0 && row < allArticles.count && "tableView:heightForRowAtIndexPath:, indexPath.row is out of bounds");

      MWFeedItem * const article = (MWFeedItem *)allArticles[row];
      return [NewsTableViewCell calculateCellHeightForData : article imageOnTheRight : (indexPath.row % 4) == 3];
   }
}

#pragma mark - RSSAggregatorDelegate methods

//________________________________________________________________________________________
- (void) allFeedsDidLoadForAggregator : (RSSAggregator *) theAggregator
{
   assert(theAggregator != nil && "allFeedsDidLoadForAggregator:, parameter 'theAggregator' is nil");

   [self copyArticlesFromAggregator];
   //
   CernAPP::WriteFeedCache(feedStoreID, feedCache, allArticles);
   feedCache = nil;

   [self hideActivityIndicators];

   usingCache = NO;

   [self.refreshControl endRefreshing];//well, if we have it active.
   [self.tableView reloadData];//we have new articles, now we can reload the table.
}

//________________________________________________________________________________________
- (void) aggregator : (RSSAggregator *) anAggregator didFailWithError : (NSString *) error
{
#pragma unused(anAggregator, error)

   [self hideActivityIndicators];

   if (usingCache || allArticles.count) {
      //We have either cache, or articles from the previous parse.
      //Do not use HUD (which hides the table's contents), just
      //show an alert.
      CernAPP::ShowErrorAlert(@"Please, check network connection", @"Close");
   } else {
      [self showErrorHUD];
   }
}

//________________________________________________________________________________________
- (void) lostConnection : (RSSAggregator *) rssAggregator
{
#pragma unused(rssAggregator)
   
   //Reachability reported network status change, while parser was still working.
   //Show an alert message.
   CernAPP::ShowErrorAlert(@"Please, check network!", @"Close");

   if (!usingCache && !allArticles.count)
      [self showErrorHUD];
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

   UIStoryboard * const mainStoryboard = [UIStoryboard storyboardWithName : @"iPhone" bundle : nil];
   ArticleDetailViewController * const viewController = [mainStoryboard instantiateViewControllerWithIdentifier : CernAPP::ArticleDetailViewControllerID];
   const NSUInteger row = indexPath.row;

   if (usingCache) {
      if (row >= feedCache.count)
         return;

      NSManagedObject * const feedItem = feedCache[row];
      [viewController setLink : (NSString *)[feedItem valueForKey : @"itemLink"]
                      title : (NSString *)[feedItem valueForKey : @"itemTitle"]];
      viewController.navigationItem.title = @"";
      
      viewController.canUseReadability = !isTwitterFeed;
      //
      viewController.articleID = [feedStoreID stringByAppendingString : (NSString *)[feedItem valueForKey : @"itemTitle"]];
      //
      [self.navigationController pushViewController : viewController animated : YES];
   } else {
      if (row >= allArticles.count)//Ooops, cell was tapped while refreshing???
         return;

      MWFeedItem * const feedItem = (MWFeedItem *)allArticles[row];

      [viewController setContentForArticle : feedItem];
      viewController.navigationItem.title = @"";

      if (feedItem.title && feedStoreID)
         viewController.articleID = [feedStoreID stringByAppendingString : feedItem.title];

      viewController.canUseReadability = !isTwitterFeed;
      [self.navigationController pushViewController : viewController animated : YES];
   }

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
   [aggregator stopAggregator];
   [self cancelAllImageDownloaders];
}

//________________________________________________________________________________________
- (void) cancelAllImageDownloaders
{
   if (imageDownloaders && imageDownloaders.count) {
      NSEnumerator * const keyEnumerator = [imageDownloaders keyEnumerator];
      for (id key in keyEnumerator) {
         ImageDownloader * const downloader = (ImageDownloader *)imageDownloaders[key];
         [downloader cancelDownload];
      }
      
      imageDownloaders = nil;
   }
   
   nLoadedImages = 0;
}

#pragma mark - UIScrollView delegate.

// Load images for all onscreen rows (if not done yet) when scrolling is finished
//________________________________________________________________________________________
- (void) scrollViewDidEndDragging : (UIScrollView *) scrollView willDecelerate : (BOOL) decelerate
{
#pragma unused(scrollView)

   //Cached feeds do not have any images.
   if (!usingCache) {
      if (!decelerate) {
         if (nLoadedImages != allArticles.count)
            [self loadImagesForOnscreenRows];
      }
   }
}

//________________________________________________________________________________________
- (void) scrollViewDidEndDecelerating : (UIScrollView *) scrollView
{
#pragma unused(scrollView)

   //No images in a cached feed.
   if (!usingCache) {
      if (nLoadedImages != allArticles.count)
         [self loadImagesForOnscreenRows];
   }
}

#pragma mark - Download images for news' items in a table.

//________________________________________________________________________________________
- (void) startIconDownloadForIndexPath : (NSIndexPath *) indexPath
{
   assert(usingCache == NO && "startIconDownloadForIndexPath, controller is in a wrong mode");
   assert(indexPath != nil && "startIconDownloadForIndexPath:, parameter 'indexPath' is nil");
   
   const NSInteger row = indexPath.row;
   assert(row >= 0 && row < allArticles.count &&
          "startIconDownloadForIndexPath:, index is out of bounds");

   if (!imageDownloaders)
      imageDownloaders = [[NSMutableDictionary alloc] init];

   ImageDownloader * downloader = (ImageDownloader *)imageDownloaders[indexPath];
   if (!downloader) {//We did not start download for this image yet.
      MWFeedItem * const article = (MWFeedItem *)allArticles[indexPath.row];
      assert(article.image == nil && "startIconDownloadForIndexPath:, image was loaded already");
      
      NSString * body = article.content;
      if (!body)
         body = article.summary;
      
      if (body) {
         if (NSString * const urlString = [NewsTableViewController firstImageURLFromHTMLString : body]) {
            downloader = [[ImageDownloader alloc] initWithURLString : urlString];
            downloader.indexPathInTableView = indexPath;
            downloader.delegate = self;
            [imageDownloaders setObject : downloader forKey : indexPath];
            [downloader startDownload];//Power on.
         }
      }
   }
}

// This method is used in case the user scrolled into a set of cells that don't have their thumbnails yet.

//________________________________________________________________________________________
- (void) loadImagesForOnscreenRows
{
   assert(usingCache == NO && "loadImagesForOnscreenRows, controller is in a wrong mode");

   if (allArticles.count) {
      NSArray * const visiblePaths = [self.tableView indexPathsForVisibleRows];
      for (NSIndexPath *indexPath in visiblePaths) {
         MWFeedItem * const article = allArticles[indexPath.row];
         if (!article.image)
            [self startIconDownloadForIndexPath : indexPath];
      }
   }
}

#pragma mark - ImageDownloaderDelegate.

//________________________________________________________________________________________
+ (NSString *) firstImageURLFromHTMLString : (NSString *) htmlString
{
   //This trick/method is taken from the v.1 of our app.
   //Author - Eamon Ford (with my modifications).

   if (!htmlString)
      return nil;

   NSScanner * const theScanner = [NSScanner scannerWithString : htmlString];
   //Find the start of IMG tag
   [theScanner scanUpToString : @"<img" intoString : nil];
   
   if (![theScanner isAtEnd]) {
      [theScanner scanUpToString : @"src" intoString : nil];
      NSCharacterSet * const charset = [NSCharacterSet characterSetWithCharactersInString : @"\"'"];
      [theScanner scanUpToCharactersFromSet : charset intoString : nil];
      [theScanner scanCharactersFromSet : charset intoString : nil];
      NSString *urlString = nil;
      [theScanner scanUpToCharactersFromSet : charset intoString : &urlString];
      // "url" now contains the URL of the img
      return urlString;
   }

   // if no img url was found, return nil
   return nil;
}

//________________________________________________________________________________________
- (void) imageDidLoad : (NSIndexPath *) indexPath
{
   assert(usingCache == NO && "imageDidLoad:, controller is in a wrong mode");

   assert(indexPath != nil && "imageDidLoad, parameter 'indexPath' is nil");
   const NSInteger row = indexPath.row;
   assert(row >= 0 && row < allArticles.count && "imageDidLoad:, index is out of bounds");
   
   MWFeedItem * const article = (MWFeedItem *)allArticles[row];
   //We should not load any image more when once.
   assert(article.image == nil && "imageDidLoad:, image was loaded already");
   
   ImageDownloader * const downloader = (ImageDownloader *)imageDownloaders[indexPath];
   assert(downloader != nil && "imageDidLoad:, no downloader found for the given index path");

   if (downloader.image) {
      article.image = downloader.image;
      [self.tableView reloadRowsAtIndexPaths : @[indexPath] withRowAnimation : UITableViewRowAnimationNone];
   }
   
   ++nLoadedImages;
   [imageDownloaders removeObjectForKey : indexPath];
}

//________________________________________________________________________________________
- (void) imageDownloadFailed : (NSIndexPath *) indexPath
{
   assert(usingCache == NO && "imageDownloadFailed:, controller is in a wrong mode");
   assert(indexPath != nil && "imageDownloadFailed:, parameter 'indexPath' is nil");

   const NSInteger row = indexPath.row;
   //Even if download failed, index still must be valid.
   assert(row >= 0 && row < allArticles.count &&
          "imageDownloadFailed:, index is out of bounds");
   assert(imageDownloaders[indexPath] != nil &&
          "imageDownloadFailed:, no downloader for the given path");
   
   ++nLoadedImages;//Still, we count this image.
   [imageDownloaders removeObjectForKey : indexPath];
   //But no need to update the tableView.
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
   UIBarButtonItem * barButton = [[UIBarButtonItem alloc] initWithCustomView : navBarSpinner];
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

@end
