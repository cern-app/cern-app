#import <algorithm>
#import <cstdlib>

#import <QuartzCore/QuartzCore.h>

#import "ArticleDetailViewController.h"
#import "ECSlidingViewController.h"
#import "NewsTableViewController.h"
#import "FeedTileViewController.h"
#import "StoryboardIdentifiers.h"
#import "ApplicationErrors.h"
#import "BulletinPageView.h"
#import "FeedItemTileView.h"
#import "FeedPageView.h"
#import "MWFeedItem.h"
#import "FeedCache.h"


using CernAPP::ControllerMode;

@implementation FeedTileViewController {
   NSUInteger nPages;
   UIView<TiledPage> *leftPage;
   UIView<TiledPage> *currPage;
   UIView<TiledPage> *rightPage;

   NSUInteger pageBeforeRotation;
   
   NSMutableDictionary *imageDownloaders;
   BOOL viewDidAppear;
   
   NSMutableArray *allArticles;

   //
   NSArray *feedCache;
   UIActivityIndicatorView *navBarSpinner;
}

@synthesize mode, aggregator, feedStoreID, noConnectionHUD, spinner;

//________________________________________________________________________________________
- (void) doInitController
{
   //Shared method for different "ctors".
   mode = ControllerMode::feedView;
   
   nPages = 0;
   leftPage = nil;
   currPage = nil;
   rightPage = nil;

   pageBeforeRotation = 0;
   imageDownloaders = nil;
   viewDidAppear = NO;
   allArticles = nil;
   
   aggregator = [[RSSAggregator alloc] init];
   aggregator.delegate = self;
   
   feedCache = nil;
}

//________________________________________________________________________________________
- (id) initWithCoder : (NSCoder *) aDecoder
{
   if (self = [super initWithCoder : aDecoder]) {
      [self doInitController];
      
      [[NSNotificationCenter defaultCenter] addObserver : self selector : @selector(articleSelected:) name : CernAPP::tileSelectionNotification object : nil];
   }

   return self;
}

//________________________________________________________________________________________
- (void) dealloc
{
   [[NSNotificationCenter defaultCenter] removeObserver : self];
}

//________________________________________________________________________________________
- (void) viewDidLoad
{
   [super viewDidLoad];
   
   CernAPP::AddSpinner(self);
   CernAPP::HideSpinner(self);
   
   if (mode != CernAPP::ControllerMode::bulletinView) {
      leftPage = [[FeedPageView alloc] initWithFrame : CGRect()];
      currPage = [[FeedPageView alloc] initWithFrame : CGRect()];
      rightPage = [[FeedPageView alloc] initWithFrame : CGRect()];
   } else {
      leftPage = [[BulletinPageView alloc] initWithFrame : CGRect()];
      currPage = [[BulletinPageView alloc] initWithFrame : CGRect()];
      rightPage = [[BulletinPageView alloc] initWithFrame : CGRect()];
   }
   
   scrollView.checkDragging = YES;
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

      if (mode != ControllerMode::bulletinIssueView) {
         if ((feedCache = CernAPP::ReadFeedCache(feedStoreID))) {
            //Set the data from the cache at the beginning!
            NSMutableArray * const cachedArticles = CernAPP::ConvertFeedCache(feedCache);
            if (mode == ControllerMode::bulletinView)
               [self sortArticlesIntoIssues : cachedArticles];
            else
               allArticles = cachedArticles;
            [self setPagesData];
         }
      }

      [self reloadPage];
   }
}

//________________________________________________________________________________________
- (void) viewWillAppear : (BOOL) animated
{
   //TODO: find a better ("idiomatic") solution for this problem.
   if (nPages) {
      //it can happen, that we have a wrong geometry: detail view
      //controller was pushed on a stack, we rotate a device and press
      //a 'back' button. geometry is wrong now.
      if (currPage && currPage.frame.size.width) {
         const CGRect currentFrame = self.view.frame;
         if (currentFrame.size.width != currPage.frame.size.width)
            [self layoutPages : YES];
      }
   }
   
   if (mode == ControllerMode::bulletinIssueView)
      //No "refresh" button, it's one level up in a navigation hierarchy.
      self.navigationItem.rightBarButtonItem = nil;
}

#pragma mark - Layout.

//________________________________________________________________________________________
- (void) layoutPages : (BOOL) layoutTiles
{
   if (!nPages)
      return;
   
   CGRect currentFrame = self.view.frame;
   currentFrame.origin = CGPoint();

   if (nPages <= 3) {
      UIView<TiledPage> * const pages[3] = {leftPage, currPage, rightPage};
      //Do not do any magic, we have only <= 3 pages.
      for (NSUInteger i = 0; i < nPages; ++i) {
         pages[i].frame = currentFrame;
         if (layoutTiles)
            [pages[i] layoutTiles];
         currentFrame.origin.x += currentFrame.size.width;
      }
   } else {
      currentFrame.origin.x = currPage.pageNumber * currentFrame.size.width;
      currPage.frame = currentFrame;
      
      CGRect leftFrame = currentFrame;
      if (currPage.pageNumber)
         leftFrame.origin.x -= leftFrame.size.width;
      else
         leftFrame.origin.x += 2 * leftFrame.size.width;
      
      leftPage.frame = leftFrame;
      
      CGRect rightFrame = currentFrame;
      if (currPage.pageNumber + 1 < nPages)
         rightFrame.origin.x += rightFrame.size.width;
      else
         rightFrame.origin.x -= 2 * rightFrame.size.width;
      
      rightPage.frame = rightFrame;
      
      if (layoutTiles) {
         [leftPage layoutTiles];
         [currPage layoutTiles];
         [rightPage layoutTiles];
      }
   }
   
   [scrollView setContentSize : CGSizeMake(currentFrame.size.width * nPages, currentFrame.size.height)];
}

#pragma mark - Device orientation changes.

//________________________________________________________________________________________
- (void) willRotateToInterfaceOrientation : (UIInterfaceOrientation) toInterfaceOrientation duration : (NSTimeInterval) duration
{
   pageBeforeRotation = NSUInteger(scrollView.contentOffset.x / scrollView.frame.size.width);
}


//________________________________________________________________________________________
- (void) willAnimateRotationToInterfaceOrientation : (UIInterfaceOrientation) toInterfaceOrientation duration : (NSTimeInterval) duration
{
   if (!nPages)
      return;

   [scrollView setContentOffset : CGPointMake(pageBeforeRotation * self.view.frame.size.width, 0.f) animated : NO];

   if (nPages <= 3) {
      UIView<TiledPage> * const pages[3] = {leftPage, currPage, rightPage};
      
      if (pageBeforeRotation)
         pages[pageBeforeRotation - 1].hidden = YES;
      if (pageBeforeRotation + 1 < nPages)
         pages[pageBeforeRotation + 1].hidden = YES;

      [self layoutPages : YES];

      [pages[pageBeforeRotation] explodeTiles : toInterfaceOrientation];
      [pages[pageBeforeRotation] collectTilesAnimatedForOrientation : toInterfaceOrientation from : CACurrentMediaTime() + duration withDuration : 0.5f];
   } else {
      leftPage.hidden = YES;
      rightPage.hidden = YES;

      [self layoutPages : YES];

      [currPage explodeTiles : toInterfaceOrientation];
      [currPage collectTilesAnimatedForOrientation : toInterfaceOrientation from : CACurrentMediaTime() + duration withDuration : 0.5f];
   }
}

//________________________________________________________________________________________
- (void) didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
   if (!nPages)
      return;

   if (nPages <= 3) {
      UIView<TiledPage> * const pages[3] = {leftPage, currPage, rightPage};
      if (pageBeforeRotation)
         pages[pageBeforeRotation - 1].hidden = NO;
      if (pageBeforeRotation + 1 < nPages)
         pages[pageBeforeRotation + 1].hidden = NO;
   } else {
      leftPage.hidden = NO;
      rightPage.hidden = NO;
   }
}

#pragma mark - Sliding view.
//________________________________________________________________________________________
- (void) revealMenu : (id) sender
{
   [self.slidingViewController anchorTopViewTo : ECRight];
}

#pragma mark - RSSAggregatorDelegate.
//________________________________________________________________________________________
- (void) allFeedsDidLoadForAggregator : (RSSAggregator *) anAggregator
{
#pragma unused(anAggregator)

   assert(mode != ControllerMode::bulletinIssueView &&
          "allFeedsDidLoadForAggregator:, wrong controller's mode");

   //In this mode we always write a cache into the storage.
   assert(feedStoreID.length && "allFeedDidLoadForAggregator:, feedStoreID is invalid");
   CernAPP::WriteFeedCache(feedStoreID, feedCache, aggregator.allArticles);

   if (mode == ControllerMode::bulletinView)
      [self sortArticlesIntoIssues : aggregator.allArticles];
   else
      allArticles = [aggregator.allArticles mutableCopy];
   
   if (feedCache) {
      feedCache = nil;
      //We were using cache and had a spinner in a nav bar (while loading a new data).
      [self hideNavBarSpinner];
   } else
      CernAPP::HideSpinner(self);
   
   self.navigationItem.rightBarButtonItem.enabled = YES;
   
   //Let's define an image layout for a tile.
   if (mode != ControllerMode::bulletinView) {
      for (MWFeedItem *item in allArticles) {
         item.wideImageOnTop = std::rand() % 2;
         item.imageCut = std::rand() % 4;
      }
   }
   
   [self setPagesData];
}

//________________________________________________________________________________________
- (void) aggregator : (RSSAggregator *) aggregator didFailWithError : (NSString *) errorDescription
{
   //TODO: error handling.
}

//________________________________________________________________________________________
- (void) lostConnection : (RSSAggregator *) aggregator
{
   //TODO: error handling.
}

#pragma mark - PageController.
//________________________________________________________________________________________
- (void) reloadPage
{
   if (aggregator.isLoadingData)
      return;

   //Stop any image download if we have any.
   [self cancelAllImageDownloaders];

   if (!aggregator.hasConnection && !allArticles.count) {
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


#pragma mark - ImageDownloaderDelegate.
//________________________________________________________________________________________
- (void) imageDidLoad : (NSIndexPath *) indexPath
{
   assert(feedCache == nil && "imageDidLoad:, images loaded while cache is in use");

   assert(indexPath != nil && "imageDidLoad, parameter 'indexPath' is nil");
   const NSInteger page = indexPath.row;
   assert(page >= 0 && page < nPages && "imageDidLoad:, index is out of bounds");
   
   MWFeedItem * const article = (MWFeedItem *)allArticles[indexPath.section];
   //We should not load any image more when once.
   assert(article.image == nil && "imageDidLoad:, image was loaded already");
   
   ImageDownloader * const downloader = (ImageDownloader *)imageDownloaders[indexPath];
   assert(downloader != nil && "imageDidLoad:, no downloader found for the given index path");

   if (downloader.image) {
      article.image = downloader.image;
      //
      if (nPages <= 3) {
         UIView<TiledPage> * pageToUpdate = nil;
         if (!page)
            pageToUpdate = leftPage;
         else if (page == 1)
            pageToUpdate = currPage;
         else
            pageToUpdate = rightPage;

         [pageToUpdate setThumbnail : article.image forTile : indexPath.section % 6];
      } else {
         if (currPage.pageNumber == page)
            [currPage setThumbnail : article.image forTile : indexPath.section % 6];
      }
   }
   
   [imageDownloaders removeObjectForKey : indexPath];
   if (!imageDownloaders.count)
      imageDownloaders = nil;
}

//________________________________________________________________________________________
- (void) imageDownloadFailed : (NSIndexPath *) indexPath
{
   assert(feedCache == nil && "imageDownloadFailed:, images loaded while cache is in use");

   assert(indexPath != nil && "imageDownloadFailed:, parameter 'indexPath' is nil");

   const NSInteger page = indexPath.row;
   //Even if download failed, index still must be valid.
   assert(page >= 0 && page < nPages &&
          "imageDownloadFailed:, index is out of bounds");
   assert(imageDownloaders[indexPath] != nil &&
          "imageDownloadFailed:, no downloader for the given path");

   [imageDownloaders removeObjectForKey : indexPath];
   //But no need to update the tableView.
   if (!imageDownloaders.count)
      imageDownloaders = nil;
}

#pragma mark - Connection controller.
//________________________________________________________________________________________
- (void) cancelAnyConnections
{
}


#pragma mark - UIScrollView delegate.

// Load images for all onscreen rows (if not done yet) when scrolling is finished


//________________________________________________________________________________________
- (void) scrollViewDidEndDragging : (UIScrollView *) aScrollView willDecelerate : (BOOL) decelerate
{
#pragma unused(aScrollView)
   //Cached feeds do not have any images.
   if (!decelerate) {
      if (nPages > 3)
         [self adjustPages];

      if (!feedCache)
         [self loadImagesForVisiblePage];
   }
}

//________________________________________________________________________________________
- (void) scrollViewDidEndDecelerating : (UIScrollView *) aScrollView
{
#pragma unused(aScrollView)
   if (nPages > 3)
      [self adjustPages];
   
   if (!feedCache)
      [self loadImagesForVisiblePage];
}

#pragma mark - Aux.

//________________________________________________________________________________________
- (void) sortArticlesIntoIssues : (NSArray *) articles
{
   assert(articles != nil && "sortArticlesIntoIssues:, parameter 'articles' is nil");
   assert(mode == ControllerMode::bulletinView && "sortArticlesIntoIssues:, wrong controller's mode");

   if (articles.count) {
      if (allArticles)
         [allArticles removeAllObjects];
      else
         allArticles = [[NSMutableArray alloc] init];
   
      NSMutableArray *weekData = [[NSMutableArray alloc] init];
      MWFeedItem * const firstArticle = [articles objectAtIndex : 0];
      firstArticle.subsetIndex = 0;
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
            [allArticles addObject : weekData];
            currentWeek = dateComponents.week;
            currentYear = dateComponents.year;
            weekData = [[NSMutableArray alloc] init];
         }
         
         //Set special parameters for a tiled page view.
         article.wideImageOnTop = std::rand() % 2;
         article.imageCut = std::rand() % 4;
         //
         article.subsetIndex = allArticles.count;
         [weekData addObject : article];
      }
      
      for (unsigned i = 0; i < 10; ++i) {
   //   [allArticles addObject : weekData];
   //   [allArticles addObject : weekData];
   //   [allArticles addObject : weekData];
      }
   }
}

//________________________________________________________________________________________
- (void) removeAllPages
{
   if (leftPage.superview)
      [leftPage removeFromSuperview];
   if (currPage.superview)
      [currPage removeFromSuperview];
   if (rightPage.superview)
      [rightPage removeFromSuperview];
}

//________________________________________________________________________________________
- (void) setPagesData
{
   //Let's define an image layout for a tile.
   
   if (mode != CernAPP::ControllerMode::bulletinView) {
      for (MWFeedItem *item in allArticles) {
         item.wideImageOnTop = std::rand() % 2;
         item.imageCut = std::rand() % 4;
      }
   }
   
   if ((nPages = [self numberOfPages])) {
      //Let's create tiled view now.
      UIView<TiledPage> * pages[3] = {};
      if (nPages <= 3)
         pages[0] = leftPage, pages[1] = currPage, pages[2] = rightPage;
      else
         pages[0] = currPage, pages[1] = rightPage, pages[2] = leftPage;

      for (NSUInteger pageIndex = 0, currentItem = 0, e = std::min((int)nPages, 3); pageIndex < e; ++pageIndex) {
         UIView<TiledPage> * const page = pages[pageIndex];
         page.pageNumber = pageIndex;
         currentItem += [page setPageItems : allArticles startingFrom : currentItem];
         if (!page.superview)
            [scrollView addSubview : page];
      }

      [self layoutPages : YES];
      [scrollView setContentOffset : CGPointMake(0.f, 0.f)];
      //The first page is visible now, let's download ... IMAGES NOW!!! :)
      if (!feedCache)
         [self loadImagesForVisiblePage];
   } else
      [self removeAllPages];
}

//________________________________________________________________________________________
- (void) adjustPages
{
   assert(nPages > 3 && "adjustPages, nPages must be > 3");
   
   const NSUInteger newCurrentPageIndex = NSUInteger(scrollView.contentOffset.x / scrollView.frame.size.width);
   if (newCurrentPageIndex == currPage.pageNumber)
      return;
   
   if (newCurrentPageIndex > currPage.pageNumber) {
      //We scrolled to the left.
      //The old 'current' becomes the new 'left'.
      //The old 'right' becomes the new 'current'.
      //The old 'left' becomes the new 'right' and we either have to set this the page or not.

      const bool leftEdge = !currPage.pageNumber;
      UIView<TiledPage> * const oldLeft = leftPage;
      leftPage = currPage;
      currPage = rightPage;
      rightPage = oldLeft;

      if (newCurrentPageIndex + 1 < nPages && !leftEdge) {
         //Set the frame first.
         CGRect frame = rightPage.frame;
         frame.origin.x = currPage.frame.origin.x + frame.size.width;
         rightPage.frame = frame;
         //Set the data now.
         [rightPage setPageItems : allArticles startingFrom : currPage.pageRange.location + currPage.pageRange.length];
         
         [rightPage layoutTiles];
      } 
   } else {
      //We scrolled to the right.
      //The old 'current' becomes the new 'right.
      //The old 'left' becomes the new 'current'.
      //The old 'right' becomes the new 'left' and we either have to set this page or not.
      
      const bool rightEdge = currPage.pageNumber + 1 == nPages;
      UIView<TiledPage> * const oldRight = rightPage;
      rightPage = currPage;
      currPage = leftPage;
      leftPage = oldRight;
      
      if (newCurrentPageIndex && !rightEdge) {
         CGRect frame = leftPage.frame;
         frame.origin.x = currPage.frame.origin.x - frame.size.width;
         leftPage.frame = frame;
         //Set the data now.
         const NSRange range = [leftPage.class suggestRangeBackward : allArticles endingWith : currPage.pageRange.location];
         [leftPage setPageItems : allArticles startingFrom : range.location];

         [leftPage layoutTiles];
      }
   }
   
   currPage.pageNumber = newCurrentPageIndex;
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
}

//________________________________________________________________________________________
- (NSUInteger) numberOfPagesForData : (NSArray *) items
{
   assert(items != nil && "numberOfPagesForData:, parameter 'items' is nil");
   assert(leftPage != nil && "numberOfpagesForData:, none of the pre-loaded pages exists");

   NSUInteger pages = 0;
   NSRange range = {};
   while (range.location + range.length < items.count) {
      ++pages;
      range = [leftPage.class suggestRangeForward : items startingFrom : range.location + range.length];
   }

   return pages;
}

//________________________________________________________________________________________
- (NSUInteger) numberOfPages
{
   return [self numberOfPagesForData : allArticles];
}

//________________________________________________________________________________________
- (NSRange) findItemRangeForPage : (NSUInteger) page
{
   assert(page < nPages && "findItemRangeForPage:, parameter 'page' is out of bounds");
   
   //Ugly, inefficient, but .. we never have a huge number of pages :)
   NSRange range = {};
   for (NSUInteger i = 0; i <= page; ++i)
      range = [leftPage.class suggestRangeForward : allArticles startingFrom : range.location + range.length];
   
   return range;
}

//________________________________________________________________________________________
- (void) loadImagesForVisiblePage
{
   assert(feedCache == nil && "loadImagesForVisiblePage, images loaded while cache is in use");
   
   if (mode == CernAPP::ControllerMode::bulletinView)//TODO!!!
      return;

   const NSUInteger visiblePage = NSUInteger(scrollView.contentOffset.x / scrollView.frame.size.width);

   const NSRange range = [self findItemRangeForPage : visiblePage];
   for (NSUInteger i = range.location, e = range.location + range.length; i < e; ++i) {
      MWFeedItem * const article = (MWFeedItem *)allArticles[i];
      if (!article.image) {
         if (!imageDownloaders)
            imageDownloaders = [[NSMutableDictionary alloc] init];
      

         //May be, we already have a downloader for this item?
         NSIndexPath * const indexPath = [NSIndexPath indexPathForRow : visiblePage inSection : i];//Using absolute index i, not relative (on a page).
         ImageDownloader *downloader = (ImageDownloader *)imageDownloaders[indexPath];
         
         if (!downloader) {
            NSString * body = article.content;
            if (!body)
               body = article.summary;

            if (NSString * const urlString = [NewsTableViewController firstImageURLFromHTMLString : body]) {
               downloader = [[ImageDownloader alloc] initWithURLString : urlString];
               downloader.indexPathInTableView = indexPath;
               downloader.delegate = self;
               [imageDownloaders setObject : downloader forKey : indexPath];
               [downloader startDownload];//Power on.
            }
         }
      } else if (nPages > 3 && ![currPage tileHasThumbnail : i - range.location]) {
         //Image was loaded already, but not tile's thumbnailView and
         //tile's layout has to be corrected yet.
         [currPage setThumbnail : article.image forTile : i - range.location];
      }
   }
}

#pragma mark - Interactions.
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

@end
