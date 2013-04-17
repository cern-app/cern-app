#import <cstdlib>

#import "BulletinFeedViewController.h"
#import "NewsTableViewController.h"
#import "BulletinIssueTileView.h"
#import "BulletinPageView.h"
#import "MWFeedItem.h"
#import "FeedCache.h"

@implementation BulletinFeedViewController

#pragma mark - Lifecycle.

- (void) doInitController
{
   imageDownloaders = nil;
}

//________________________________________________________________________________________
- (id) initWithCoder : (NSCoder *) aDecoder
{
   if (self = [super initWithCoder : aDecoder])
      [self doInitController];

   return self;
}

//Observer is removed in the NewsFeedViewController's dealloc.

#pragma mark - RSSAggregatorDelegate.

//________________________________________________________________________________________
- (void) allFeedsDidLoadForAggregator : (RSSAggregator *) anAggregator
{
#pragma unused(anAggregator)
   //In this mode we always write a cache into the storage.
   assert(self.feedStoreID.length && "allFeedDidLoadForAggregator:, feedStoreID is invalid");
   CernAPP::WriteFeedCache(self.feedStoreID, feedCache, self.aggregator.allArticles);

   [self sortArticlesIntoIssues : self.aggregator.allArticles];
   
   if (feedCache) {
      feedCache = nil;
      //We were using cache and had a spinner in a nav bar (while loading a new data).
      [self hideNavBarSpinner];
   } else
      CernAPP::HideSpinner(self);
   
   self.navigationItem.rightBarButtonItem.enabled = YES;
   [self setPagesData];
}

#pragma mark - Overriders for TileViewController's methods.

//________________________________________________________________________________________
- (void) loadVisiblePageData
{
   assert(feedCache == nil && "loadVisiblePageData, images loaded while cache is in use");

   const NSUInteger visiblePageIndex = NSUInteger(scrollView.contentOffset.x / scrollView.frame.size.width);
   UIView<TiledPage> *visiblePage = nil;
   if (nPages > 3)
      visiblePage = currPage;
   else
      !visiblePageIndex ? visiblePage = leftPage : visiblePageIndex == 1 ? visiblePage = currPage : visiblePage = rightPage;

   const NSRange range = visiblePage.pageRange;
   for (NSUInteger i = range.location, e = range.location + range.length; i < e; ++i) {
      assert(i < dataItems.count && "loadVisiblePageData, invalid range for a page");

      //Does a tile have a thumbnail already?
      if ([visiblePage tileHasThumbnail : i - range.location])
         continue;
      
      //Check, if some article in this issue has a good image.
      NSArray * const articles = (NSArray *)dataItems[i];
      bool imageFound = false;
      for (MWFeedItem *article in articles) {
         if (article.image) {
            imageFound = true;
            [visiblePage setThumbnail : article.image forTile : i - range.location];
            break;
         }
      }

      if (imageFound)
         continue;

      if (!imageDownloaders)
         imageDownloaders = [[NSMutableDictionary alloc] init];      
      
      NSUInteger articleIndex = 0;
      for (MWFeedItem *article in articles) {
         NSIndexPath * const key = [NSIndexPath indexPathForRow : i inSection : visiblePageIndex];
         ImageDownloader * downloader = (ImageDownloader *)imageDownloaders[key];
         if (downloader)//We are already downloading image for this tile.
            break;

         NSString * body = article.content;
         if (!body)
            body = article.summary;
         
         if (NSString * const urlString = [NewsTableViewController firstImageURLFromHTMLString : body]) {
            downloader = [[ImageDownloader alloc] initWithURLString : urlString];
            const NSUInteger indices[] = {visiblePageIndex, i, articleIndex};
            downloader.indexPathInTableView = [[NSIndexPath alloc] initWithIndexes : indices length : 3];
            downloader.delegate = self;
            [imageDownloaders setObject : downloader forKey : key];
            [downloader startDownload];//Power on.
            break;
         }
         ++articleIndex;
      }
   }
}

#pragma mark - Overriders for NewsFeedViewController's methods.

//________________________________________________________________________________________
- (void) createPages
{
   leftPage = [[BulletinPageView alloc] initWithFrame : CGRect()];
   currPage = [[BulletinPageView alloc] initWithFrame : CGRect()];
   rightPage = [[BulletinPageView alloc] initWithFrame : CGRect()];
}

//________________________________________________________________________________________
- (void) addTileTapObserver
{
   [[NSNotificationCenter defaultCenter] addObserver : self selector : @selector(bulletinIssueSelected:) name : CernAPP::bulletinIssueSelectionNotification object : nil];
}

//________________________________________________________________________________________
- (void) initTilesFromCache
{
   assert(self.feedStoreID != nil && "initCache, invalid feedStoreID");

   //
   if ((feedCache = CernAPP::ReadFeedCache(self.feedStoreID))) {
      //Set the data from the cache at the beginning!
      NSMutableArray * const cachedArticles = CernAPP::ConvertFeedCache(feedCache);
      [self sortArticlesIntoIssues : cachedArticles];
      [self setPagesData];
   }
}

//________________________________________________________________________________________
- (void) setTilesLayoutHints
{
   //Noop: in a bulletin it's up to a page view to set hints.
}

#pragma mark - ImageDownloaderDelegate.

//________________________________________________________________________________________
- (void) imageDidLoad : (NSIndexPath *) indexPath
{
   assert(indexPath != nil && "imageDidLoad:, parameter 'indexPath' is nil");
   assert(indexPath.length == 3 && "imageDidLoad:, parameter 'indexPath' is not a valid path");

   NSUInteger indices[3] = {};
   [indexPath getIndexes : indices];
   
   const NSUInteger pageIndex = indices[0];
   assert(pageIndex < nPages && "imageDidLoad:, page index is out of bounds");
   const NSRange pageRange = [self findItemRangeForPage : pageIndex];
   assert(pageRange.location + pageRange.length <= dataItems.count &&
          "imageDidLoad:, page range is invalid");

   UIView<TiledPage> *pageToUpdate = nil;
   if (nPages <= 3)
      pageToUpdate = !pageIndex ? leftPage : pageIndex == 1 ? currPage : rightPage;
   else if (currPage.pageNumber == pageIndex)
      pageToUpdate = currPage;
   
   const NSUInteger tileIndex = indices[1];
   assert(tileIndex >= pageRange.location && tileIndex < pageRange.location + pageRange.length &&
          "imageDidLoad:, tile index is out of bounds");
   NSArray * const articles = (NSArray *)dataItems[tileIndex];
   const NSUInteger articleIndex = indices[2];
   assert(articleIndex < articles.count && "imageDidLoad:, article index is out of bounds");
   
   NSIndexPath * const key2D = [NSIndexPath indexPathForRow : tileIndex inSection : pageIndex];
   ImageDownloader * const downloader = (ImageDownloader *)imageDownloaders[key2D];
   assert(downloader != nil && "imageDidLoad:, downloader not found for index path");
   MWFeedItem * const article = (MWFeedItem *)articles[articleIndex];

   if (!article.image)//Yes, it can be also downloaded by the BulletinIssueViewController. Ufff.
      article.image = downloader.image;

   [imageDownloaders removeObjectForKey : key2D];
   
   if (pageToUpdate)
      [pageToUpdate setThumbnail:article.image forTile : tileIndex - pageRange.location];
   
   if (!imageDownloaders.count)
      imageDownloaders = nil;
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

   UIView<TiledPage> *pageToUpdate = nil;
   if (nPages <= 3)
      pageToUpdate = !pageIndex ? leftPage : pageIndex == 1 ? currPage : rightPage;
   else if (currPage.pageNumber == pageIndex)
      pageToUpdate = currPage;
   
   const NSUInteger tileIndex = indices[1];
   assert(tileIndex >= pageRange.location && tileIndex < pageRange.location + pageRange.length &&
          "imageDownloadFailed:, tile index is out of bounds");
   NSArray * const articles = (NSArray *)dataItems[tileIndex];
   const NSUInteger articleIndex = indices[2];
   assert(articleIndex < articles.count && "imageDownloadFailed:, article index is out of bounds");
   
   NSIndexPath * const key2D = [NSIndexPath indexPathForRow : tileIndex inSection : pageIndex];
   ImageDownloader *downloader = (ImageDownloader *)imageDownloaders[key2D];
   assert(downloader != nil && "imageDownloadFailed:, downloader not found for index path");

   [imageDownloaders removeObjectForKey : key2D];
   
   if (pageToUpdate) {
      //We still can try to load the next thumbnail.
      if (self.aggregator.hasConnection && articleIndex + 1 < articles.count) {//May be, download failed because of network problems?
         for (NSUInteger i = articleIndex + 1, e = articles.count; i < e; ++i) {
            MWFeedItem * const nextArticle = (MWFeedItem *)articles[i];
            NSString * body = nextArticle.content;
            if (!body)
               body = nextArticle.summary;
         
            if (NSString * const urlString = [NewsTableViewController firstImageURLFromHTMLString : body]) {
               downloader = [[ImageDownloader alloc] initWithURLString : urlString];
               const NSUInteger indices[] = {pageIndex, tileIndex, i};
               downloader.indexPathInTableView = [[NSIndexPath alloc] initWithIndexes : indices length : 3];
               downloader.delegate = self;
               [imageDownloaders setObject : downloader forKey : key2D];
               [downloader startDownload];//Power on.
               break;
            }
         }
      }
   }
   
   if (!imageDownloaders.count)
      imageDownloaders = nil;
}

#pragma mark - User interactions.

//________________________________________________________________________________________
- (void) bulletinIssueSelected : (NSNotification *) notification
{
#pragma unused(notification)
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
