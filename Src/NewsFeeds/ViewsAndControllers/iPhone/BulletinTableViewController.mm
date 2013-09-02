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
#import "HUDRefreshProtocol.h"
#import "NewsTableViewCell.h"
#import "ApplicationErrors.h"
#import "AppDelegate.h"
#import "GUIHelpers.h"
#import "FeedCache.h"

@interface NewsTableViewController(Private)

- (void) hideActivityIndicators;
- (void) showErrorHUD;

@end

@implementation BulletinTableViewController {
   NSMutableArray *bulletins;
   NSMutableDictionary *thumbnails;
   NSMutableDictionary *imageDownloaders;
}

//________________________________________________________________________________________
- (id) initWithCoder : (NSCoder *) aDecoder
{
   if (self = [super initWithCoder : aDecoder]) {
      bulletins = nil;
      thumbnails = nil;
      imageDownloaders = nil;
   }

   return self;
}

#pragma mark - some overrides from NewsTableViewController.

//________________________________________________________________________________________
- (BOOL) initFromAppCache
{
   assert(self.feedStoreID != nil && "initFromAppCache, feedStoreID is nil");
   assert([[UIApplication sharedApplication].delegate isKindOfClass : [AppDelegate class]] &&
          "initFromAppCache, app delegate has a wrong type");
   
   bulletins = [(AppDelegate *)[UIApplication sharedApplication].delegate cacheForFeed : self.feedStoreID];
   thumbnails = [[NSMutableDictionary alloc] init];
   
   return bulletins != nil;
}

//________________________________________________________________________________________
- (BOOL) initFromDBCache
{
   assert(self.feedStoreID != nil && "initFromDBCache, feedStoreID is nil");
   
   if ((feedCache = CernAPP::ReadFeedCache(self.feedStoreID))) {
      //Convert persistent objects into feed items.
      NSMutableArray * const articles = CernAPP::ConvertFeedCache(feedCache);
      [self splitIntoIssues : articles];
      thumbnails = [[NSMutableDictionary alloc] init];

      return YES;
   }
   
   return NO;
}

//________________________________________________________________________________________
- (void) addContentsToAppCache
{
   //Add new articles to the app's cache (not split into the issues).
   assert(self.feedStoreID != nil && "addContentsToAppCache:, feedStoreID is nil");
   assert([[UIApplication sharedApplication].delegate isKindOfClass : [AppDelegate class]] &&
          "addContentsToAppCache:, app delegate has a wrong type");
   assert(bulletins != nil && "addContentsToAppCache, nothing to add");
   
   [(AppDelegate *)[UIApplication sharedApplication].delegate cacheData : bulletins forFeed : self.feedStoreID];
}

//________________________________________________________________________________________
- (void) reloadShowHUD : (BOOL) show
{
   //This function is called either the first time we are loading table
   //or after 'pull-refresh', in this case, we do not show
   //spinner (it's done by refreshControl).
   if (parseOp)
      return;

   //Stop an image download if we have any.
   [self cancelAllImageDownloaders];

   if (![self hasConnection]) {
      //Network problems, we can not reload
      //and do not have any previous data to show.
      if (!bulletins || !bulletins.count) {
         [self showErrorHUD];
         return;
      }
   }

   [noConnectionHUD hide : YES];
   [MBProgressHUD hideAllHUDsForView : self.view animated : NO];

   if (show) {
      [spinner setHidden : NO];
      [spinner startAnimating];
   }

   [self startFeedParsing];
}

#pragma mark - UITableViewDataSource and aux. methods.

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
- (UIImage *) imageForCell : (NSIndexPath *) indexPath
{
   assert(indexPath != nil && "imageForCell, parameter 'indexPath' is nil");
   
   if (UIImage * const thumbnailImage = (UIImage *)thumbnails[indexPath])
      return thumbnailImage;
   
   assert(indexPath.row >= 0 && indexPath.row < bulletins.count &&
          "imageForCell:, row index is out of bounds");
   
   NSArray * const articles = (NSArray *)bulletins[indexPath.row];
   assert(articles.count > 0 && "imageForCell:, no articles for issue found");
      
   for (MWFeedItem *article in articles) {
      if (article.image)
         return article.image;
   }
   
   return nil;
}

//________________________________________________________________________________________
- (UITableViewCell *) tableView : (UITableView *) tableView cellForRowAtIndexPath : (NSIndexPath *) indexPath
{
   assert(tableView != nil && "tableView:cellForRowAtIndexPath:, parameter 'tableView' is nil");
   assert(indexPath != nil && "tableView:cellForRowAtIndexPath:, parameter 'indexPath' is nil");

   const NSInteger row = indexPath.row;
   assert(row >= 0 && row < bulletins.count && "tableView:cellForRowAtIndexPath:, index is out of bounds");

   UITableViewCell *cell = (NewsTableViewCell *)[tableView dequeueReusableCellWithIdentifier : [NewsTableViewCell cellReuseIdentifier]];
   assert((!cell || [cell isKindOfClass : [NewsTableViewCell class]]) &&
          "tableView:cellForRowAtIndexPath:, reusable cell is either nil or has a wrong type");
   if (!cell)
      cell = [[NewsTableViewCell alloc] initWithFrame : [NewsTableViewCell defaultCellFrame]];

   if (![cell.selectedBackgroundView isKindOfClass : [CellBackgroundView class]])
      cell.backgroundView = [[CellBackgroundView alloc] initWithFrame : CGRect()];

   UIImage * const image = [thumbnails objectForKey : indexPath];
   [(NewsTableViewCell *)cell setTitle : CernAPP::BulletinTitleForWeek((NSArray *)bulletins[row]) image : image];

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
   NSString * const title = CernAPP::BulletinTitleForWeek((NSArray *)bulletins[row]);
   return [NewsTableViewCell calculateCellHeightWithText : title image : image];
}

#pragma mark - FeedParserOperationDelegate and aux. methods.

//________________________________________________________________________________________
- (void) splitIntoIssues : (NSArray *) articles
{
   assert(articles != nil && "splitIntoIssues:, parameter 'articles' is nil");
   assert(articles.count > 0 && "splitIntoIssues:, no data to split");
   
   bulletins = [[NSMutableArray alloc] init];
   thumbnails = [[NSMutableDictionary alloc] init];
   
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
         [bulletins addObject : weekData];
         currentWeek = dateComponents.week;
         currentYear = dateComponents.year;
         weekData = [[NSMutableArray alloc] init];
      }

      [weekData addObject : article];
   }
      
   [bulletins addObject : weekData];
}

//________________________________________________________________________________________
- (void) parserDidFinishWithInfo : (MWFeedInfo *) info items : (NSArray *) articles
{
#pragma unused(info)

   assert(articles != nil && "parserDidFinishWithInfo:, parameter 'articles' is nil");
   
   [self hideActivityIndicators];

   //Here we split sorted (by date) articles into the bulletin's issues (by week).
   if (articles.count) {
      [self splitIntoIssues : articles];
      
      CernAPP::WriteFeedCache(self.feedStoreID, feedCache, articles);
      feedCache = nil;
      
      [self addContentsToAppCache];
      [self.tableView reloadData];
   }
   
   parseOp = nil;
}

//________________________________________________________________________________________
- (void) parserDidFailWithError : (NSError *) error
{
#pragma unused(error)
   [self hideActivityIndicators];

   parseOp = nil;

   if (self.navigationController.topViewController == self)//There can be bulletin issue view controller above 'self'.
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
   vc.issueID = CernAPP::BulletinTitleForWeek((NSArray *)bulletins[indexPath.row]);
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

   if (!imageDownloaders)
      imageDownloaders = [[NSMutableDictionary alloc] init];

   ImageDownloader * downloader = (ImageDownloader *)imageDownloaders[indexPath];
   if (!downloader) {//We did not start download for this image yet.
      NSArray * const articles = (NSArray *)bulletins[indexPath.row];
      assert(articles.count > 0 && "startIconDownloadForIndexPath, no articles for issue found");
      
      for (MWFeedItem *article in articles) {
         NSString * body = article.content;
         if (!body)
            body = article.summary;
         
         if (body) {
            if (NSString * const urlString = CernAPP::FirstImageURLFromHTMLString(body)) {
            
               downloader = [[ImageDownloader alloc] initWithURLString : urlString];
               downloader.indexPathInTableView = indexPath;
               //
               downloader.dataSizeLimit = 500000;
               downloader.downscaleToSize = 150.f;
               //
               downloader.delegate = self;
               [imageDownloaders setObject : downloader forKey : indexPath];
               [downloader startDownload];//Power on.
               break;
            }
         }
      }
   }
}

// This method is used in case the user scrolled into a set of cells that don't have their thumbnails yet.

//________________________________________________________________________________________
- (void) loadImagesForOnscreenRows
{
   if (bulletins.count) {
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
   assert(indexPath != nil && "imageDidLoad:, parameter 'indexPath' is nil");
   const NSInteger row = indexPath.row;
   assert(row >= 0 && row < bulletins.count && "imageDidLoad:, index is out of bounds");
   
   //We should not load any image more when once.
   assert(thumbnails[indexPath] == nil && "imageDidLoad:, image was loaded already");
   
   ImageDownloader * const downloader = (ImageDownloader *)imageDownloaders[indexPath];
   assert(downloader != nil && "imageDidLoad:, no downloader found for a given index path");
   
   if (downloader.image) {
      [thumbnails setObject : downloader.image forKey : indexPath];
      [self.tableView reloadRowsAtIndexPaths : @[indexPath] withRowAnimation : UITableViewRowAnimationNone];
   }
   
   [imageDownloaders removeObjectForKey : indexPath];
}

//________________________________________________________________________________________
- (void) imageDownloadFailed : (NSIndexPath *) indexPath
{
   assert(indexPath != nil && "imageDownloadFailed:, parameter 'indexPath' is nil");
   assert(indexPath.row >= 0 && indexPath.row < bulletins.count &&
          "imageDownloadFailed:, row index is out of bounds");
   
   assert(imageDownloaders[indexPath] != nil &&
          "imageDownloadFailed:, no downloader forund for a given index path");
   
   [imageDownloaders removeObjectForKey : indexPath];
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

#pragma mark - Interface rotation.

//________________________________________________________________________________________
- (BOOL) shouldAutorotate
{
   return NO;
}

@end

namespace CernAPP {

//________________________________________________________________________________________
NSString *BulletinTitleForWeek(NSArray *articles)
{
   assert(articles.count != 0 && "BulletinDateForWeek, parameter 'articles' is nil or an empty array");
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

}
