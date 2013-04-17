#import <cstdlib>

#import "BulletinFeedViewController.h"
#import "BulletinIssueTileView.h"
#import "BulletinPageView.h"
#import "MWFeedItem.h"
#import "FeedCache.h"

@implementation BulletinFeedViewController {
   NSMutableDictionary *imageDownloaders;
   NSMutableDictionary *thumbnails;
}

#pragma mark - Lifecycle.

- (void) doInitController
{
   imageDownloaders = nil;
   thumbnails = nil;
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
   assert(feedCache == nil && "loadImagesForVisiblePage, images loaded while cache is in use");
   //TODO.
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
   //Noop: in a bulletin it's up to page view to set hints.
}

#pragma mark - ImageDownloaderDelegate.

//________________________________________________________________________________________
- (void) imageDidLoad : (NSIndexPath *) indexPath
{
#pragma unused(indexPath)
}

//________________________________________________________________________________________
- (void) imageDownloadFailed : (NSIndexPath *) indexPath
{
#pragma unused(indexPath)
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
