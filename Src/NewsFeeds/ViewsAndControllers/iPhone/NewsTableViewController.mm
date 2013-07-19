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
#import "Reachability.h"
#import "AppDelegate.h"
#import "GUIHelpers.h"
#import "FeedCache.h"
#import "KeyVal.h"

namespace CernAPP {

//________________________________________________________________________________________
NSString *FirstImageURLFromHTMLString(NSString *htmlString)
{
   //This trick/code is taken from the v.1 of our app.
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

   //No img url was found.
   return nil;
}

}

@implementation NewsTableViewController {
   NSMutableArray *allArticles;
   
   NSArray *feedCache;
   
   UIActivityIndicatorView *navBarSpinner;
   BOOL firstViewDidAppear;
   
   NSString *feedURLString;
   NSOperationQueue *parseQueue;
   
   Reachability *internetReach;
   
   NSMutableArray *rangeDownloaders;
   
   BOOL lowMemory;

   NSArray *feedFilters;
}

@synthesize feedStoreID;


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
   canUseCache = YES;
   spinner = nil;
   noConnectionHUD = nil;
   parseOp = nil;
   feedStoreID = nil;

   //'private' ivars (hidden in mm file).
   allArticles = nil;
   feedCache = nil;
   navBarSpinner = nil;
   firstViewDidAppear = YES;

   feedURLString = nil;
   parseQueue = [[NSOperationQueue alloc] init];

   internetReach = [Reachability reachabilityForInternetConnection];
   
   rangeDownloaders = nil;
   
   lowMemory = NO;
   feedFilters = nil;
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
         if ((feedCache = CernAPP::ReadFeedCache(feedStoreID)))
            //Convert persistent objects into feed items.
            allArticles = CernAPP::ConvertFeedCache(feedCache);
      }
      
      [self.tableView reloadData];//Load table with cached data, if any.
      [self reload];
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

   //Actually, nothing I can do here. I tried to release images - did not help,
   //app keeps dying. Quite a useless method.
   
   [parseQueue cancelAllOperations];
   parseOp = nil;
   [self cancelAllImageDownloaders];

   lowMemory = YES;
   allArticles = nil;
   [self.tableView reloadData];
   
//   [[NSURLCache sharedURLCache] removeAllCachedResponses];
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

   CernAPP::WriteFeedCache(feedStoreID, feedCache, items);

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


   feedCache = nil;

   [self hideActivityIndicators];

   parseOp = nil;

   [self.refreshControl endRefreshing];//well, if we have it active.
   [self.tableView reloadData];//we have new articles, now we can reload the table.
   [self loadImagesForOnscreenRows];
}

//________________________________________________________________________________________
- (void) parserDidFailWithError : (NSError *) error
{
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

   UIStoryboard * const mainStoryboard = [UIStoryboard storyboardWithName : @"iPhone" bundle : nil];
   ArticleDetailViewController * const viewController = [mainStoryboard instantiateViewControllerWithIdentifier : CernAPP::ArticleDetailViewControllerID];
   [viewController setContentForArticle : feedItem];
   viewController.navigationItem.title = @"";

   if (feedItem.title && feedStoreID)
      viewController.articleID = [feedStoreID stringByAppendingString : feedItem.title];

   viewController.canUseReadability = YES;
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
   if (!feedCache) {
      if (!decelerate)
         [self loadImagesForOnscreenRows];
   }
}

//________________________________________________________________________________________
- (void) scrollViewDidEndDecelerating : (UIScrollView *) scrollView
{
#pragma unused(scrollView)

   //No images in a cached feed.
   if (!feedCache)
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

   if (lowMemory)
      return;

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
         
            if (body) {
               if (NSString * const urlString = CernAPP::FirstImageURLFromHTMLString(body)) {
                  KeyVal * const newThumbnail = [[KeyVal alloc] init];
                  newThumbnail.key = indexPath;
                  newThumbnail.val = urlString;
                  [pairs addObject : newThumbnail];
               }
            }
         }
      }
         
      if (pairs.count) {
         ThumbnailDownloader * const pageDownloader = [[ThumbnailDownloader alloc] initWithItems : pairs sizeLimit : 500000 downscaleToSize : 150.f];
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
