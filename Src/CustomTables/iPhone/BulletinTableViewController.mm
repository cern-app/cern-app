//
//  BulletinTableViewController.m
//  CERN
//
//  Created by Timur Pocheptsov on 1/17/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

#import "BulletinIssueTableViewController.h"
#import "BulletinTableViewController.h"
#import "StoryboardIdentifiers.h"
#import "CellBackgroundView.h"
#import "NewsTableViewCell.h"
#import "ApplicationErrors.h"
#import "GUIHelpers.h"

@interface NewsTableViewController(Private)

- (void) hideActivityIndicators;
- (void) showErrorHUD;

@end

@implementation BulletinTableViewController {
   NSMutableArray *bulletins;
   NSMutableDictionary *thumbnails;
}

//________________________________________________________________________________________
- (id) initWithCoder : (NSCoder *) aDecoder
{
   return self = [super initWithCoder : aDecoder];
}

//________________________________________________________________________________________
- (void) viewDidLoad
{
   [super viewDidLoad];
	//Do any additional setup after loading the view.
}

//________________________________________________________________________________________
- (void) viewDidAppear : (BOOL) animated
{
   canUseCache = NO;
   [super viewDidAppear : animated];
}

//________________________________________________________________________________________
- (void) didReceiveMemoryWarning
{
   [super didReceiveMemoryWarning];
   //Dispose of any resources that can be recreated.
}

//

//This method is overriden (it differs from what I have in NewsTableViewController.

//________________________________________________________________________________________
- (void) reloadPageShowHUD : (BOOL) show
{
   //This function is called either the first time we are loading table
   //(if we have a cache, we show spinner in a nav-bar, if no - in the center),
   //and it can be also called after 'pull-refresh', in this case, we do not show
   //spinner (it's done by refreshControl).

   if (self.aggregator.isLoadingData)
      return;
   
   //Stop any image download if we have any.
   [self cancelAllImageDownloaders];

   if (!self.aggregator.hasConnection) {
      //Network problems, we can not reload
      //and do not have any previous data to show.
      if (!bulletins || !bulletins.count) {
         [self showErrorHUD];
         return;
      }
   }

   [noConnectionHUD hide : YES];
   
   if (show) {
      //HUD: either spinner in the center
      //or spinner in a navigation bar.
      [spinner setHidden : NO];
      [spinner startAnimating];
   }

   [self.aggregator clearAllFeeds];
   [self.aggregator refreshAllFeeds];
}

#pragma mark - Aux. functions.

//________________________________________________________________________________________
- (NSString *) titleForIssue : (NSUInteger) index
{
   assert(index < bulletins.count && "titleForIssue:, parameter 'index' is out of bounds");

   NSArray * const articles = (NSArray *)bulletins[index];
   assert(articles.count != 0 && "titleForIssue:, not articles found");

   //Set the title for a bulletin - "Week " + date of the week beginning day for this article.
   MWFeedItem * const latestArticle = (MWFeedItem *)articles[articles.count - 1];

   //Formatter to create a string representation.
   NSDateFormatter * const dateFormatter = [[NSDateFormatter alloc] init];
   dateFormatter.dateStyle = NSDateFormatterMediumStyle;

   //Weekday of the article's date
   NSDateComponents * const dateComponents = [[NSCalendar currentCalendar] components : NSWeekdayCalendarUnit fromDate : latestArticle.date];

   NSString *issueDateString = nil;
   if (dateComponents.weekday > 1) {
      NSDate * const firstDay = [latestArticle.date dateByAddingTimeInterval : -(dateComponents.weekday - 1) * 24 * 60 * 60];
      issueDateString = [dateFormatter stringFromDate:firstDay];
   } else {
      issueDateString = [dateFormatter stringFromDate : latestArticle.date];
   }
   
   return [NSString stringWithFormat : @"Week %@", issueDateString];
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
#pragma unused(tableView)
   // Return the number of rows in the section.
   return bulletins.count;
}

//________________________________________________________________________________________
- (UITableViewCell *) tableView : (UITableView *) tableView cellForRowAtIndexPath : (NSIndexPath *) indexPath
{
   assert(tableView != nil && "tableView:cellForRowAtIndexPath:, parameter 'tableView' is nil");
   assert(indexPath != nil && "tableView:cellForRowAtIndexPath:, parameter 'indexPath' is nil");

   const NSInteger row = indexPath.row;
   assert(row >= 0 && row < bulletins.count && "tableView:cellForRowAtIndexPath:, index is out of bounds");

   UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier : @"BulletinCell"];
   assert(!cell || [cell isKindOfClass : [NewsTableViewCell class]] &&
          "tableView:cellForRowAtIndexPath:, reusable cell has a wrong type");

   if (!cell)
      cell = [[NewsTableViewCell alloc] initWithFrame : [NewsTableViewCell defaultCellFrame]];

   if (![cell.selectedBackgroundView isKindOfClass : [CellBackgroundView class]])
      cell.backgroundView = [[CellBackgroundView alloc] initWithFrame : CGRect()];

   NewsTableViewCell * const newsCell = (NewsTableViewCell *)cell;
   UIImage * const image = [thumbnails objectForKey : indexPath];
   [newsCell setTitle : [self titleForIssue : row] image : image];

   if (!image)
      [self startIconDownloadForIndexPath : indexPath];

   return cell;
}

//________________________________________________________________________________________
- (CGFloat) tableView : (UITableView *) tableView heightForRowAtIndexPath : (NSIndexPath *) indexPath
{
#pragma unused(tableView)

   assert(indexPath != nil && "tableView:heightForRowAtIndexPath:, parameter 'indexPath' is nil");

   const NSInteger row = indexPath.row;
   assert(row >= 0 && row < bulletins.count && "tableView:heightForRowAtIndexPath:, index is out of bounds");

   UIImage * const image = [thumbnails objectForKey : [NSNumber numberWithInteger : row]];
   return [NewsTableViewCell calculateCellHeightWithText : [self titleForIssue : row] image : image];
}

#pragma mark - RSSAggregatorDelegate methods

//________________________________________________________________________________________
- (void) allFeedsDidLoadForAggregator : (RSSAggregator *) theAggregator
{
   assert(theAggregator != nil && "allFeedsDidLoadForAggregator:, parameter 'theAggregator' is nil");

   [self hideActivityIndicators];

   //
   //Split articles into groups using week number.
   //

   if (theAggregator.allArticles.count) {
      bulletins = [[NSMutableArray alloc] init];
      thumbnails = [[NSMutableDictionary alloc] init];
   
      NSArray * const articles = theAggregator.allArticles;//Aggregator already has sorted them by date.
   
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
            [bulletins addObject : weekData];
            currentWeek = dateComponents.week;
            currentYear = dateComponents.year;
            weekData = [[NSMutableArray alloc] init];
         }
         
         article.subsetIndex = bulletins.count;
         [weekData addObject : article];
      }
      
      [bulletins addObject : weekData];
      
      [self.tableView reloadData];
   }
}

//________________________________________________________________________________________
- (void) aggregator : (RSSAggregator *) aggregator didFailWithError : (NSString *) error
{
   [MBProgressHUD hideAllHUDsForView : self.view animated : NO];
   noConnectionHUD = [MBProgressHUD showHUDAddedTo : self.view animated : NO];

   noConnectionHUD.mode = MBProgressHUDModeText;
   if (error)
      noConnectionHUD.labelText = error;
   else
      noConnectionHUD.labelText = @"Load error";
   noConnectionHUD.removeFromSuperViewOnHide = YES;
   
   [spinner stopAnimating];
   [spinner setHidden : YES];
   [self.refreshControl  endRefreshing];
}

//________________________________________________________________________________________
- (void) lostConnection : (RSSAggregator *) rssAggregator
{
#pragma unused(rssAggregator)
   
   //Reachability reported network status change, while parser was still working.
   //Show an alert message.
   CernAPP::ShowErrorAlert(@"Please, check network!", @"Close");

   if (!bulletins || !bulletins.count)
      [self showErrorHUD];
}

#pragma mark - Table view delegate

//________________________________________________________________________________________
- (void) tableView : (UITableView *) tableView didSelectRowAtIndexPath : (NSIndexPath *) indexPath
{
   assert(tableView != nil && "tableView:didSelectRowAtIndexPath:, parameter 'tableView' is nil");
   assert(indexPath != nil && "tableView:didSelectRowAtIndexPath, parameter 'indexPath' is nil");
   
   if (indexPath.row < 0 || indexPath.row >= bulletins.count)
      return;

   UIStoryboard * const mainStoryboard = [UIStoryboard storyboardWithName : @"iPhone" bundle : nil];
   BulletinIssueTableViewController * const vc = [mainStoryboard instantiateViewControllerWithIdentifier : CernAPP::BulletinIssueTableControllerID];
   vc.tableData = bulletins[indexPath.row];
   vc.issueID = [self titleForIssue : indexPath.row];
   [self.navigationController pushViewController : vc animated : YES];

   [tableView deselectRowAtIndexPath : indexPath animated : NO];
}

#pragma mark - Thumbnails.


//________________________________________________________________________________________
- (void) startIconDownloadForIndexPath : (NSIndexPath *) indexPath
{
   assert(indexPath != nil && "startIconDownloadForIndexPath:, parameter 'indexPath' is nil");
   const NSInteger row = indexPath.row;
   assert(row >= 0 && row < bulletins.count &&
          "startIconDownloadForIndexPath:, index is out of bounds");

   if (!self.imageDownloaders)
      self.imageDownloaders = [[NSMutableDictionary alloc] init];

   ImageDownloader * downloader = (ImageDownloader *)self.imageDownloaders[indexPath];
   if (!downloader) {//We did not start download for this image yet.
      NSArray * const articles = (NSArray *)bulletins[indexPath.row];
      assert(articles.count > 0 && "startIconDownloadForIndexPath, no articles for issue found");
      
      for (MWFeedItem *article in articles) {
         //If we are here, this means we do not have a thumbnail
         //yet, but in principle, some of articles in this issue
         //can have an image downloaded already (I had an
         //an assert here).
         if (article.image) {
            //
            [thumbnails setObject : article.image forKey : indexPath];
            [self.tableView reloadRowsAtIndexPaths : @[indexPath] withRowAnimation : UITableViewRowAnimationNone];
            break;
         } else {
            NSString * body = article.content;
            if (!body)
               body = article.summary;
            
            if (body) {
               if (NSString * const urlString = [NewsTableViewController firstImageURLFromHTMLString : body]) {
                  downloader = [[ImageDownloader alloc] initWithURLString : urlString];
                  downloader.indexPathInTableView = indexPath;
                  downloader.delegate = self;
                  [self.imageDownloaders setObject : downloader forKey : indexPath];
                  [downloader startDownload];//Power on.
                  break;
               }
            }
         }
      }
   }
}

// This method is used in case the user scrolled into a set of cells that don't have their thumbnails yet.

//________________________________________________________________________________________
- (void) loadImagesForOnscreenRows
{
   if (bulletins.count && self.nLoadedImages != bulletins.count) {
      NSArray * const visiblePaths = [self.tableView indexPathsForVisibleRows];
      for (NSIndexPath *indexPath in visiblePaths) {
         if (!thumbnails[indexPath])
            [self startIconDownloadForIndexPath : indexPath];
      }
   }
}

//________________________________________________________________________________________
- (void) imageDidLoad : (NSIndexPath *) indexPath
{
   //
   assert(indexPath != nil && "imageDidLoad, parameter 'indexPath' is nil");
   const NSInteger row = indexPath.row;
   assert(row >= 0 && row < bulletins.count && "imageDidLoad:, index is out of bounds");
   
   //We should not load any image more when once.
   assert(thumbnails[indexPath] == nil && "imageDidLoad:, image was loaded already");
   
   ImageDownloader * const downloader = (ImageDownloader *)self.imageDownloaders[indexPath];
   assert(downloader != nil && "imageDidLoad:, no downloader found for the given index path");
   
   if (downloader.image) {
      [thumbnails setObject : downloader.image forKey : indexPath];
      [self.tableView reloadRowsAtIndexPaths : @[indexPath] withRowAnimation : UITableViewRowAnimationNone];
   }
   
   ++self.nLoadedImages;
   [self.imageDownloaders removeObjectForKey : indexPath];
}

#pragma mark - Interface rotation.

//________________________________________________________________________________________
- (BOOL) shouldAutorotate
{
   return NO;
}

@end
