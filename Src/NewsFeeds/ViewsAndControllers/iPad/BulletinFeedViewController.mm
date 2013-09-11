#import <cstdlib>

#import "BulletinIssueViewController.h"
#import "BulletinTableViewController.h"
#import "BulletinFeedViewController.h"
#import "NewsTableViewController.h"
#import "StoryboardIdentifiers.h"
#import "BulletinIssueTileView.h"
#import "BulletinPageView.h"
#import "AppDelegate.h"
#import "MWFeedItem.h"
#import "FeedCache.h"
#import "FlipView.h"

@implementation BulletinFeedViewController

#pragma mark - Lifecycle.

//________________________________________________________________________________________
- (id) initWithCoder : (NSCoder *) aDecoder
{
   if (self = [super initWithCoder : aDecoder]) {
      downloaders = nil;
   }

   return self;
}

//Observer is removed in the NewsFeedViewController's dealloc.

#pragma mark - FeedParserOperationDelegate.

//________________________________________________________________________________________
- (void) parserDidFinishWithInfo : (MWFeedInfo *) info items : (NSArray *) items
{
#pragma unused(info)

   assert(items != nil && "parserDidFinishWithInfo:items:, parameter 'items' is nil");
   
   assert(self.feedCacheID.length && "allFeedDidLoadForAggregator:, feedCacheID is invalid");
   CernAPP::WriteFeedCache(self.feedCacheID, feedCache, items);

   [self sortArticlesIntoIssues : items];
   
   if (feedCache) {
      feedCache = nil;
      //We were using cache and had a spinner in a nav bar (while loading a new data).
      [self hideNavBarSpinner];
   } else
      CernAPP::HideSpinner(self);
   
   parserOp = nil;

   //Cache data in app delegate.
   [self cacheInAppDelegate];
   //
   
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
   [self setPagesData];

   [self layoutPages : YES];
   [self layoutFlipView];

   [self loadVisiblePageData];
   
   if (nPages > 1)
      [self showRightFlipHint];
   else
      [self hideFlipHint];
}

#pragma mark - Overriders for TileViewController's methods.

//________________________________________________________________________________________
- (void) loadVisiblePageData
{
   if (feedCache || parserOp)//We're refreshing, do not load images, anyway, at the end of refresh
      return;                //operation they'll become invalid (potentially).
   

   const CGFloat minImageSize = [BulletinIssueTileView minImageSize];

   bool updateFlip = false;
   const NSRange range = currPage.pageRange;
   for (NSUInteger i = range.location, e = range.location + range.length; i < e; ++i) {
      assert(i < dataItems.count && "loadVisiblePageData, invalid range for a page");

      //Does a tile have a thumbnail already?
      if ([currPage tileHasThumbnail : i - range.location])
         continue;
      
      //Check, if some article in this issue has a good image.
      NSArray * const articles = (NSArray *)dataItems[i];
      bool imageFound = false;
      for (MWFeedItem *article in articles) {
         if (article.image) {
            const CGSize imageSize = article.image.size;
            if (imageSize.width >= minImageSize && imageSize.height >= minImageSize) {
               imageFound = true;
               [currPage setThumbnail : article.image forTile : i - range.location doLayout : YES];
               updateFlip = true;
               break;
            }
         }
      }

      if (imageFound)
         continue;

      if (!downloaders)//In the base class it was a dictionary with ThumbnailDownloaders, now it's a dictionary with ImageDownloaders.
         downloaders = [[NSMutableDictionary alloc] init];
      
      NSUInteger articleIndex = 0;
      for (MWFeedItem *article in articles) {
         if (article.image)//We skip this image (it was checked in the first loop, but seems to be not large enough).
            continue;
      
         NSIndexPath * const key = [NSIndexPath indexPathForRow : i inSection : currPage.pageNumber];
         ImageDownloader * downloader = (ImageDownloader *)downloaders[key];
         if (downloader)//We are already downloading image for this tile.
            break;

         NSString * body = article.content;
         if (!body)
            body = article.summary;
         
         if (NSString * const urlString = CernAPP::FirstImageURLFromHTMLString(body)) {
            downloader = [[ImageDownloader alloc] initWithURLString : urlString];
            downloader.dataSizeLimit = 1000000;
            const NSUInteger indices[] = {currPage.pageNumber, i, articleIndex};
            downloader.indexPathInTableView = [[NSIndexPath alloc] initWithIndexes : indices length : 3];
            downloader.delegate = self;
            [downloaders setObject : downloader forKey : key];
            [downloader startDownload];//Power on.
            break;
         }
         ++articleIndex;
      }
   }
   
   if (updateFlip) {
      [currPage layoutTiles];
      [flipView replaceCurrentFrame : currPage];
   }
}

#pragma mark - Overriders for NewsFeedViewController's methods.

//________________________________________________________________________________________
- (void) createPages
{
   prevPage = [[BulletinPageView alloc] initWithFrame : CGRect()];
   currPage = [[BulletinPageView alloc] initWithFrame : CGRect()];
   nextPage = [[BulletinPageView alloc] initWithFrame : CGRect()];
}

//________________________________________________________________________________________
- (void) addTileTapObserver
{
   [[NSNotificationCenter defaultCenter] addObserver : self selector : @selector(bulletinIssueSelected:) name : CernAPP::bulletinIssueSelectionNotification object : nil];
}

//________________________________________________________________________________________
- (BOOL) initTilesFromDBCache
{
   assert(self.feedCacheID != nil && "initFromDBCache, invalid feedCacheID");

   //
   if ((feedCache = CernAPP::ReadFeedCache(self.feedCacheID))) {
      //Set the data from the cache at the beginning!
      NSMutableArray * const cachedArticles = CernAPP::ConvertFeedCache(feedCache);
      [self sortArticlesIntoIssues : cachedArticles];
      [self setPagesData];
      
      return YES;
   }
   
   return NO;
}

//________________________________________________________________________________________
- (BOOL) initTilesFromAppCache
{
   assert(self.feedCacheID != nil && "initTilesFromAppCache, feedCacheID is nil");
   assert([[UIApplication sharedApplication].delegate isKindOfClass : [AppDelegate class]] &&
          "initTilesFromAppCache:, app delegate has a wrong type");
   
   if (NSObject * const cache = [(AppDelegate *)[UIApplication sharedApplication].delegate cacheForKey : self.feedCacheID]) {
      assert([cache isKindOfClass : [NSMutableArray class]] &&
             "initTilesFromAppCache, cached object has a wrong type");
      dataItems = (NSMutableArray *)cache;
      [self setPagesData];
   }
   
   return dataItems != nil;
}

//________________________________________________________________________________________
- (void) cacheInAppDelegate
{
   assert([[UIApplication sharedApplication].delegate isKindOfClass : [AppDelegate class]] &&
          "cacheInAppDelegate:, app delegate has a wrong type");
   AppDelegate * const appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
   [appDelegate cacheData : dataItems withKey : self.feedCacheID];
}

//________________________________________________________________________________________
- (void) setTilesLayoutHints
{
   //Noop: in a bulletin it's up to a page view to set hints.
}

//________________________________________________________________________________________
- (void) cancelAllImageDownloaders
{
   if (downloaders && downloaders.count) {
      NSEnumerator * const keyEnumerator = [downloaders keyEnumerator];
      for (id key in keyEnumerator) {
         ImageDownloader * const downloader = (ImageDownloader *)downloaders[key];
         [downloader cancelDownload];
      }
      
      downloaders = nil;
   }
}

#pragma mark - ImageDownloaderDelegate.

//________________________________________________________________________________________
- (void) imageDidLoad : (NSIndexPath *) indexPath
{
   assert(indexPath != nil && "imageDidLoad:, parameter 'indexPath' is nil");
   assert(indexPath.length == 3 && "imageDidLoad:, parameter 'indexPath' is not a valid path");

   BOOL updateFlip = NO;

   NSUInteger indices[3] = {};
   [indexPath getIndexes : indices];
   
   const NSUInteger pageIndex = indices[0];
   assert(pageIndex < nPages && "imageDidLoad:, page index is out of bounds");
   const NSRange pageRange = [self findItemRangeForPage : pageIndex];
   assert(pageRange.location + pageRange.length <= dataItems.count &&
          "imageDidLoad:, page range is invalid");
   
   const NSUInteger tileIndex = indices[1];
   assert(tileIndex >= pageRange.location && tileIndex < pageRange.location + pageRange.length &&
          "imageDidLoad:, tile index is out of bounds");
   NSArray * const articles = (NSArray *)dataItems[tileIndex];
   const NSUInteger articleIndex = indices[2];
   assert(articleIndex < articles.count && "imageDidLoad:, article index is out of bounds");
   
   NSIndexPath * const key2D = [NSIndexPath indexPathForRow : tileIndex inSection : pageIndex];
   ImageDownloader *downloader = (ImageDownloader *)downloaders[key2D];
   assert(downloader != nil && "imageDidLoad:, downloader not found for index path");

   UIImage * const newImage = downloader.image;
   [downloaders removeObjectForKey : key2D];
   
   bool imageFound = false;
   if (newImage) {
      MWFeedItem * const article = (MWFeedItem *)articles[articleIndex];
      if (!article.image)//Yes, it can be also downloaded by the BulletinIssueViewController. Ufff.
         article.image = newImage;

      const CGFloat minSize = [BulletinIssueTileView minImageSize];
      const CGSize imageSize = newImage.size;
   
      if (imageSize.width >= minSize && imageSize.height >= minSize) {
         imageFound = true;
         //Ok, we have a good image!
         if (currPage.pageNumber == pageIndex) {
            [currPage setThumbnail : newImage forTile : tileIndex - pageRange.location doLayout : YES];
            updateFlip = YES;
         }
      }
   }

   if (!imageFound && currPage.pageNumber == pageIndex) {
      for (NSUInteger i = articleIndex + 1, e = articles.count; i < e; ++i) {
         MWFeedItem * const nextArticle = (MWFeedItem *)articles[i];
         NSString * body = nextArticle.content;
         if (!body)
            body = nextArticle.summary;
         
         if (NSString * const urlString = CernAPP::FirstImageURLFromHTMLString(body)) {
            downloader = [[ImageDownloader alloc] initWithURLString : urlString];
            downloader.dataSizeLimit = 1000000;
            const NSUInteger indices[] = {pageIndex, tileIndex, i};
            downloader.indexPathInTableView = [[NSIndexPath alloc] initWithIndexes : indices length : 3];
            downloader.delegate = self;
            [downloaders setObject : downloader forKey : key2D];
            [downloader startDownload];//Power on.
            break;
         }
      }
   }
   
   if (!downloaders.count)
      downloaders = nil;
   
   if (updateFlip) {
      [currPage layoutTiles];
      [flipView replaceCurrentFrame : currPage];
   }
}

//________________________________________________________________________________________
- (void) imageDownloadFailed : (NSIndexPath *) indexPath
{
   assert(indexPath != nil && "imageDownloadFailed:, parameter 'indexPath' is nil");
   assert(indexPath.length == 3 && "imageDownloadFailed:, parameter 'indexPath' is not a valid path");

   NSUInteger indices[3] = {};
   [indexPath getIndexes : indices];
   
   const NSUInteger pageIndex = indices[0];
   assert(pageIndex < nPages && "imageDownloadFailed:, page index is out of bounds");
   const NSRange pageRange = [self findItemRangeForPage : pageIndex];
   assert(pageRange.location + pageRange.length <= dataItems.count &&
          "imageDownloadFailed:, page range is invalid");

   const NSUInteger tileIndex = indices[1];
   assert(tileIndex >= pageRange.location && tileIndex < pageRange.location + pageRange.length &&
          "imageDownloadFailed:, tile index is out of bounds");
   NSArray * const articles = (NSArray *)dataItems[tileIndex];
   const NSUInteger articleIndex = indices[2];
   assert(articleIndex < articles.count && "imageDownloadFailed:, article index is out of bounds");
   
   NSIndexPath * const key2D = [NSIndexPath indexPathForRow : tileIndex inSection : pageIndex];
   ImageDownloader *downloader = (ImageDownloader *)downloaders[key2D];
   assert(downloader != nil && "imageDownloadFailed:, downloader not found for index path");

   [downloaders removeObjectForKey : key2D];
   
   if (currPage.pageNumber == pageIndex) {
      //We still can try to load the next thumbnail.
      if ([self hasConnection] && articleIndex + 1 < articles.count) {//May be, download failed because of network problems?
         for (NSUInteger i = articleIndex + 1, e = articles.count; i < e; ++i) {
            MWFeedItem * const nextArticle = (MWFeedItem *)articles[i];
            NSString * body = nextArticle.content;
            if (!body)
               body = nextArticle.summary;
         
            if (NSString * const urlString = CernAPP::FirstImageURLFromHTMLString(body)) {
               downloader = [[ImageDownloader alloc] initWithURLString : urlString];
               downloader.dataSizeLimit = 1000000;
               const NSUInteger indices[] = {pageIndex, tileIndex, i};
               downloader.indexPathInTableView = [[NSIndexPath alloc] initWithIndexes : indices length : 3];
               downloader.delegate = self;
               [downloaders setObject : downloader forKey : key2D];
               [downloader startDownload];//Power on.
               break;
            }
         }
      }
   }
   
   if (!downloaders.count)
      downloaders = nil;
}

#pragma mark - User interactions.

//________________________________________________________________________________________
- (void) bulletinIssueSelected : (NSNotification *) notification
{
   assert(notification != nil && "bulletinIssueSelected:, parameter 'notification' is nil");
   assert([notification.object isKindOfClass : [NSNumber class]] &&
          "articleSelected:, an object in a notification has a wrong type");
   
   const NSUInteger issueNumber = [(NSNumber *)notification.object unsignedIntegerValue];
   assert(issueNumber < dataItems.count && "bulletinIssueSelected:, issue number is out of bounds");
   BulletinIssueViewController * const nextController =
                              (BulletinIssueViewController *)[self.storyboard instantiateViewControllerWithIdentifier : CernAPP::BulletinIssueViewControllerID];

   [nextController setData : (NSArray *)dataItems[issueNumber]];
   nextController.navigationItem.title = CernAPP::BulletinTitleForWeek((NSArray *)dataItems[issueNumber]);
   [self.navigationController pushViewController : nextController animated : YES];
}

#pragma mark - Aux.

//________________________________________________________________________________________
- (void) sortArticlesIntoIssues : (NSArray *) articles
{
   assert(articles != nil && "sortArticlesIntoIssues:, parameter 'articles' is nil");

   if (articles.count) {
      if (dataItems)
         [dataItems removeAllObjects];
      else
         dataItems = [[NSMutableArray alloc] init];
   
      NSMutableArray *weekData = [[NSMutableArray alloc] init];
      MWFeedItem * const firstArticle = [articles objectAtIndex : 0];
      [weekData addObject : firstArticle];
   
      NSCalendar * const calendar = [NSCalendar currentCalendar];
      const NSUInteger requiredComponents = NSWeekCalendarUnit | NSYearCalendarUnit;

      NSDateComponents *dateComponents = [calendar components : requiredComponents fromDate : firstArticle.date];
      NSInteger currentWeek = dateComponents.week;
      NSInteger currentYear = dateComponents.year;
   
      for (NSUInteger i = 1, e = articles.count; i < e; ++i) {
         MWFeedItem * const article = (MWFeedItem *)articles[i];
         dateComponents = [calendar components : requiredComponents fromDate : article.date];

         if (dateComponents.year != currentYear || dateComponents.week != currentWeek) {
            [dataItems addObject : weekData];
            currentWeek = dateComponents.week;
            currentYear = dateComponents.year;
            weekData = [[NSMutableArray alloc] init];
         }
         
         //Set special parameters for a tiled page view.
         article.wideImageOnTop = std::rand() % 2;
         article.imageCut = std::rand() % 4;
         //
         [weekData addObject : article];
      }
      
      [dataItems addObject : weekData];
   }
}

@end
