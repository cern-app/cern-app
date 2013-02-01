//
//  BulletinIssueTableViewController.m
//  CERN
//
//  Created by Timur Pocheptsov on 1/21/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import "BulletinIssueTableViewController.h"
#import "ArticleDetailViewController.h"
#import "BulletinTableViewController.h"
#import "StoryboardIdentifiers.h"
#import "ApplicationErrors.h"
#import "NewsTableViewCell.h"
#import "MWFeedItem.h"

@implementation BulletinIssueTableViewController {
   BOOL loaded;
   
   NSMutableDictionary *imageDownloaders;
}

@synthesize tableData, prevController;

//________________________________________________________________________________________
- (void) setTableData : (NSArray *) aData
{
   tableData = aData;
   loaded = NO;
}

//________________________________________________________________________________________
- (id) initWithStyle : (UITableViewStyle) style
{
   return self = [super initWithStyle : style];
}

//________________________________________________________________________________________
- (void) viewDidLoad
{
   [super viewDidLoad];
}

//________________________________________________________________________________________
- (void) viewDidAppear : (BOOL) animated
{
   assert(tableData != nil && "viewDidAppear, tableData is nil");

   [super viewDidAppear : animated];

   if (!loaded) {
      [self.tableView reloadData];
      loaded = YES;
   }
}

//________________________________________________________________________________________
- (void) didReceiveMemoryWarning
{
   [super didReceiveMemoryWarning];
   // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

//________________________________________________________________________________________
- (NSInteger) numberOfSectionsInTableView : (UITableView *) tableView
{
   return 1;
}

//________________________________________________________________________________________
- (NSInteger) tableView : (UITableView *) tableView numberOfRowsInSection : (NSInteger) section
{
#pragma unused(tableView, section)
   if (tableData)
      return tableData.count;

   return 0;
}

//________________________________________________________________________________________
- (UITableViewCell *) tableView : (UITableView *) tableView cellForRowAtIndexPath : (NSIndexPath *) indexPath
{
   assert(indexPath != nil && "tableView:cellForRowAtIndexPath:, parameter 'indexPath' is nil");

   //Find feed item first.
   const NSInteger row = indexPath.row;
   assert(row >= 0 && row < tableData.count &&
          "tableView:cellForRowAtIndexPath:, index is out of bounds");

   MWFeedItem * const article = (MWFeedItem *)tableData[row];
   assert(article != nil && "tableView:cellForRowAtIndexPath:, article was not found");

   NewsTableViewCell *cell = (NewsTableViewCell *)[tableView dequeueReusableCellWithIdentifier : @"BulletinIssueCell"];
   if (!cell)
      cell = [[NewsTableViewCell alloc] initWithFrame : [NewsTableViewCell defaultCellFrame]];

   [cell setCellData : article imageOnTheRight : (indexPath.row % 4) == 3];
   
   if (!article.image)
      [self startIconDownloadForIndexPath : indexPath];

   return cell;
}

//________________________________________________________________________________________
- (CGFloat) tableView : (UITableView *) tableView heightForRowAtIndexPath : (NSIndexPath *) indexPath
{
#pragma unused(tableView)
   assert(indexPath != nil && "tableView:heightForRowAtIndexPath:, parameter 'indexPath' is nil");

   const NSInteger row = indexPath.row;
   assert(row >= 0 && row < tableData.count && "tableView:heightForRowAtIndexPath:, indexPath.row is out of bounds");

   MWFeedItem * const article = (MWFeedItem *)tableData[row];
   return [NewsTableViewCell calculateCellHeightForData : article imageOnTheRight : (indexPath.row % 4) == 3];
}

#pragma mark - Table view delegate

//________________________________________________________________________________________
- (void) tableView : (UITableView *) tableView didSelectRowAtIndexPath : (NSIndexPath *) indexPath
{
   assert(self.navigationController != nil && "tableView:didSelectRowAtIndexPath: navigation controller is nil");
   assert(prevController != nil && "tableView:didSelectRowAtIndexPath: prevController is nil");

   if (prevController.aggregator.hasConnection) {
      UIStoryboard * const mainStoryboard = [UIStoryboard storyboardWithName : @"iPhone" bundle : nil];
      ArticleDetailViewController *viewController = [mainStoryboard instantiateViewControllerWithIdentifier : CernAPP::ArticleDetailViewControllerID];
      const NSInteger row = indexPath.row;
      assert(row >= 0 && row < tableData.count &&
             "tableView:didSelectRowAtIndexPath:, index is out of bounds");
      [viewController setContentForArticle : (MWFeedItem *)tableData[row]];
      viewController.navigationItem.title = @"";
      [self.navigationController pushViewController : viewController animated : YES];
   } else {
      CernAPP::ShowErrorAlert(@"Please, check network!", @"Close");
   }

   [tableView deselectRowAtIndexPath : indexPath animated : NO];
}

#pragma mark - Aux.

//________________________________________________________________________________________
- (void) reloadRowFor : (MWFeedItem *) article
{
   assert(article != nil && "reloadRowFor:, parameter 'article' is nil");
   assert(tableData.count && "reloadRowFor:, tableData is nil or is empty");

   const NSUInteger index = [tableData indexOfObject : article];
   assert(index != NSNotFound &&
          "reloadRowFor:, article is not found in a list of articles");

   const NSUInteger path[2] = {0, index};
   NSIndexPath * const indexPath = [NSIndexPath indexPathWithIndexes : path length : 2];
   
   [self.tableView reloadRowsAtIndexPaths : @[indexPath] withRowAnimation : UITableViewRowAnimationNone];
}

#pragma mark - ConnectionController

//________________________________________________________________________________________
- (void) cancelAnyConnections
{
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
}

#pragma mark - ImageDownloader.

// Load images for all onscreen rows when scrolling is finished
//________________________________________________________________________________________
- (void) scrollViewDidEndDragging : (UIScrollView *) scrollView willDecelerate : (BOOL) decelerate
{
#pragma unused(scrollView)
   if (!decelerate)
      [self loadImagesForOnscreenRows];
}

//________________________________________________________________________________________
- (void) scrollViewDidEndDecelerating : (UIScrollView *) scrollView
{
   [self loadImagesForOnscreenRows];
}

#pragma mark - Download images for news' items in a table.

//________________________________________________________________________________________
- (void) startIconDownloadForIndexPath : (NSIndexPath *) indexPath
{
   assert(indexPath != nil && "startIconDownloadForIndexPath:, parameter 'indexPath' is nil");
   const NSInteger row = indexPath.row;
   assert(row >= 0 && row < tableData.count &&
          "startIconDownloadForIndexPath:, index is out of bounds");
   
   if (!imageDownloaders)
      imageDownloaders = [[NSMutableDictionary alloc] init];

   ImageDownloader * downloader = (ImageDownloader *)imageDownloaders[indexPath];
   if (!downloader) {//We did not start download for this image yet.
      MWFeedItem * const article = (MWFeedItem *)tableData[indexPath.row];
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
   if (tableData.count) {
      NSArray * const visiblePaths = [self.tableView indexPathsForVisibleRows];
      for (NSIndexPath *indexPath in visiblePaths) {
         MWFeedItem * const article = tableData[indexPath.row];
         if (!article.image)
            [self startIconDownloadForIndexPath : indexPath];
      }
   }
}

#pragma mark - ImageDownloaderDelegate.

//________________________________________________________________________________________
- (void) imageDidLoad : (NSIndexPath *) indexPath
{
   //
   assert(indexPath != nil && "imageDidLoad, parameter 'indexPath' is nil");
   const NSInteger row = indexPath.row;
   assert(row >= 0 && row < tableData.count && "imageDidLoad:, index is out of bounds");
   
   MWFeedItem * const article = (MWFeedItem *)tableData[row];
   
   //We should not load any image more when once.
   assert(article.image == nil && "imageDidLoad:, image was loaded already");
   
   ImageDownloader * const downloader = (ImageDownloader *)imageDownloaders[indexPath];
   assert(downloader != nil && "imageDidLoad:, no downloader found for the given index path");
   
   if (downloader.image) {
      article.image = downloader.image;
      [self.tableView reloadRowsAtIndexPaths : @[indexPath] withRowAnimation : UITableViewRowAnimationNone];
   }

   [imageDownloaders removeObjectForKey : indexPath];
}

//________________________________________________________________________________________
- (void) imageDownloadFailed : (NSIndexPath *) indexPath
{
   assert(indexPath != nil && "imageDownloadFailed:, parameter 'indexPath' is nil");

   const NSInteger row = indexPath.row;

   //Even if download failed, index still must be valid.
   assert(row >= 0 && row < tableData.count &&
          "imageDownloadFailed:, index is out of bounds");
   assert(imageDownloaders[indexPath] != nil &&
          "imageDownloadFailed:, no downloader for the given path");
   
   [imageDownloaders removeObjectForKey : indexPath];
   //No need to update the tableView.
}

@end
