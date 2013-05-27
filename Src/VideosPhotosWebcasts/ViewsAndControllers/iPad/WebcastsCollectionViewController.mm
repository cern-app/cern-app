//
//  WebcastsViewController.m
//  CERN
//
//  Created by Timur Pocheptsov on 5/24/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <cassert>

#import "WebcastsCollectionViewController.h"
#import "ECSlidingViewController.h"
#import "NewsTableViewController.h"
#import "HUDRefreshProtocol.h"
#import "ApplicationErrors.h"
#import "WebcastViewCell.h"
#import "MBProgressHUD.h"
#import "Reachability.h"

using CernAPP::NetworkStatus;

//________________________________________________________________________________________
@implementation WebcastsCollectionViewController {   
   IBOutlet UISegmentedControl *segmentedControl;
   
   //Now I need 3 parsers for 3 different feeds (it's possible that user switched between the
   //different segments and thus all of them are loading now.
   MWFeedParser *parsers[3];
   NSArray *feedData[3];
   NSMutableArray *feedDataTmp[3];
   NSMutableDictionary *imageDownloaders[3];

   BOOL viewDidAppear;
   
   //These are additional collection views for the upcoming and recorded webcasts.
   UIView *auxParentViews[2];
   UICollectionView * auxCollectionViews[2];
   
   UIActivityIndicatorView *spinners[3];
   MBProgressHUD *noConnectionHUDs[3];
   
   Reachability *internetReach;
}

#pragma mark - Network reachability.

//TODO: check this part.

//________________________________________________________________________________________
- (void) showErrorHUDIfEmptyPage : (NSUInteger) pageIndex
{
   assert(pageIndex < 3 && "showErrorHUDIfEmptyPage:, parameter 'pageIndex' is out of bounds");
   
   if (!pageIndex && !feedData[0].count)
      CernAPP::ShowErrorHUD(self.view, @"Network error");
}

//________________________________________________________________________________________
- (void) reachabilityStatusChanged : (Reachability *) current
{
#pragma unused(current)
   
   if (internetReach && [internetReach currentReachabilityStatus] == NetworkStatus::notReachable) {
      //Depending on what we do now and what we have now ...
      [self cancelAnyConnections];
      
      for (NSUInteger i = 0; i < 3; ++i) {
         [self hideSpinnerForView : i];
         [self showErrorHUDIfEmptyPage : i];
      }

      const NSInteger index = segmentedControl.selectedSegmentIndex;
      assert(index >= 0 && index < 3 && "reachabilityStatusChanged:, selected segment is out of bounds");
      
      if (feedData[index].count) {
         //We did not show error HUD for the current page.
         CernAPP::ShowErrorAlert(@"Please, check network!", @"Close");
      }

      self.navigationItem.rightBarButtonItem.enabled = YES;
   }
}

//________________________________________________________________________________________
- (bool) hasConnection
{
   return internetReach && [internetReach currentReachabilityStatus] != NetworkStatus::notReachable;
}

#pragma mark - Lifecycle.

//________________________________________________________________________________________
- (id) initWithCoder : (NSCoder *) aDecoder
{
   if (self = [super initWithCoder : aDecoder]) {
      for (unsigned i = 0; i < 3; ++i) {
         parsers[i] = nil;
         feedData[i] = nil;
         feedDataTmp[i] = nil;
         
         imageDownloaders[i] = [[NSMutableDictionary alloc] init];
         
         spinners[i] = nil;
         noConnectionHUDs[i] = nil;
      }

      for (unsigned i = 0; i < 2; ++i) {
         auxParentViews[i] = nil;
         auxCollectionViews[i] = nil;
      }

      viewDidAppear = NO;
      
      [[NSNotificationCenter defaultCenter] addObserver : self selector : @selector(reachabilityStatusChanged:) name : CernAPP::reachabilityChangedNotification object : nil];
      internetReach = [Reachability reachabilityForInternetConnection];
   }
   
   return self;
}

//________________________________________________________________________________________
- (void) dealloc
{
   [[NSNotificationCenter defaultCenter] removeObserver : self];
}

#pragma mark - viewDid/Will/NeverDoes etc.

//________________________________________________________________________________________
- (void) viewDidLoad
{
   [super viewDidLoad];
	// Do any additional setup after loading the view.
   for (unsigned i = 0; i < 2; ++i) {
      auxParentViews[i] = [[UIView alloc] initWithFrame : CGRect()];
      auxParentViews[i].autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
                                           UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
                                           UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
      auxParentViews[i].autoresizesSubviews = YES;
      auxCollectionViews[i] = [[UICollectionView alloc] initWithFrame : CGRect() collectionViewLayout:[[UICollectionViewFlowLayout alloc] init]];
      auxCollectionViews[i].autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
                                               UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
                                               UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
      auxCollectionViews[i].dataSource = self;
      auxCollectionViews[i].delegate = self;
      
      [auxParentViews[i] addSubview : auxCollectionViews[i]];
      [self.view addSubview : auxParentViews[i]];
      
      [auxCollectionViews[i] registerClass : [WebcastViewCell class]
           forCellWithReuseIdentifier : @"WebcastViewCell"];
      
      spinners[i + 1] = CernAPP::AddSpinner(auxParentViews[i]);
      CernAPP::HideSpinner(spinners[i + 1]);
   }

   spinners[0] = CernAPP::AddSpinner(self.view);
   CernAPP::HideSpinner(spinners[0]);
   
   [internetReach startNotifier];
}

//________________________________________________________________________________________
- (void) viewWillAppear : (BOOL) animated
{
   [segmentedControl setSelectedSegmentIndex : 0];

   CGRect frame = self.collectionView.frame;
   auxParentViews[0].frame = frame;
   auxParentViews[1].frame = frame;
   
   frame.origin = CGPoint();
   auxCollectionViews[0].frame = frame;
   auxCollectionViews[1].frame = frame;

   [self.view bringSubviewToFront : self.collectionView];
}

//________________________________________________________________________________________
- (void) viewDidAppear : (BOOL) animated
{
   [super viewDidAppear : animated];

   assert(parsers[0] != nil && parsers[1] != nil && parsers[2] != nil &&
          "viewDidAppear:, not all parsers/feeds are valid");
   
   if (!viewDidAppear) {
      viewDidAppear = YES;
      //Refresh all "pages".
      [self refresh : NO];
   }
}

//________________________________________________________________________________________
- (void) didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Other methods.

//________________________________________________________________________________________
- (void) setControllerData : (NSArray *) dataItems
{
   assert(dataItems != nil && "setControllerData:, parameter 'dataItems' is nil");
   //We have 3 segments, 3 views, we need 3 links.
   assert(dataItems.count == 3 && "setControllerData:, unexpected number of items");
   //
   for (id item in dataItems) {
      assert([item isKindOfClass : [NSDictionary class]] &&
             "setControllerData:, a data item has a wrong type");
      
      NSDictionary * const itemDict = (NSDictionary *)item;
      assert([itemDict[@"Category name"] isKindOfClass : [NSString class]] &&
             "setControllerData:, 'Category name' is not found or has a wrong type");
      
      NSString * const name = (NSString *)itemDict[@"Category name"];
      assert([itemDict[@"Url"] isKindOfClass : [NSString class]] &&
             "setControllerData:, 'Url' is not found or has a wrong type");
      NSString * const urlStr = (NSString *)itemDict[@"Url"];
      
      if ([name isEqualToString:@"Live"])
         parsers[0] = [[MWFeedParser alloc] initWithFeedURL : [NSURL URLWithString : urlStr]];
      else if ([name isEqualToString : @"Upcoming"])
         parsers[1] = [[MWFeedParser alloc] initWithFeedURL : [NSURL URLWithString : urlStr]];
      else if ([name isEqualToString : @"Recent"])
         parsers[2] = [[MWFeedParser alloc] initWithFeedURL : [NSURL URLWithString : urlStr]];
      else
         assert(0 && @"setControllerData:, unknown category name for a segment");
   }
   
   assert(parsers[0] != nil && parsers[1] != nil && parsers[2] != nil &&
          "setControllerData:, not all parsers/feeds are valid");
   

   for (NSUInteger i = 0; i < 3; ++i) {
      parsers[i].delegate = self;
      parsers[i].connectionType = ConnectionTypeAsynchronously;
   }
}

//________________________________________________________________________________________
- (void) refresh : (BOOL) selectedSegmentOnly
{
   assert(parsers[0] != nil && parsers[1] != nil && parsers[2] != nil &&
          "refresh:, not all parsers/feeds are valid");
   assert(parsers[0].isParsing == NO && parsers[1].isParsing == NO && parsers[2].isParsing == NO &&
          "refresh:, called while some parser is still active");

   [self cancelAllDownloaders : selectedSegmentOnly];

   [MBProgressHUD hideAllHUDsForView : self.view animated : NO];
   assert(auxCollectionViews[0] != nil && auxCollectionViews[1] != nil &&
          "refresh:, aux. collection views were not initialized correctly");
   [MBProgressHUD hideAllHUDsForView : auxCollectionViews[0] animated : NO];
   [MBProgressHUD hideAllHUDsForView : auxCollectionViews[1] animated : NO];
   
   self.navigationItem.rightBarButtonItem.enabled = NO;
   
   [self startParsing : selectedSegmentOnly];
   [self showSpinners : selectedSegmentOnly];   
}

#pragma mark - Feed parsers and related methods.

//________________________________________________________________________________________
- (BOOL) allParsersFinished
{
   return !parsers[0].isParsing && !parsers[1].isParsing && !parsers[2].isParsing;
}

//________________________________________________________________________________________
- (NSUInteger) indexForParser : (MWFeedParser *) parser
{
   assert(parser != nil && "indexForParser:, parameter 'parser' is nil");
   
   for (NSUInteger i = 0; i < 3; ++i) {
      if (parsers[i] == parser)
         return i;
   }
   
   assert(0 && "indexForParser:, parser not found");
   
   return 0;
}

//________________________________________________________________________________________
- (void) feedParser : (MWFeedParser *) feedParser didParseFeedItem:(MWFeedItem *) item
{
   assert(feedParser != nil && "feedParser:didParseFeedItem:, parameter 'feedParser' is nil");
   assert(item != nil && "feedParser:didParseFeedItem:, parameter 'item' is nil");

   NSMutableArray *data = nil;
   for (unsigned i = 0; i < 3; ++i) {
      if (feedParser == parsers[i]) {
         data = feedDataTmp[i];
         break;
      }
   }
   
   assert(data != nil && "feedParser:didParseFeedItem:, unknown parser");
   [data addObject : item];
}


//________________________________________________________________________________________
- (void) feedParser : (MWFeedParser *) feedParser didFailWithError : (NSError *) error
{
#pragma unused(error)

   assert(feedParser != nil && "feedParser:didFailWithError:, parameter 'feedParser' is nil");

   const NSUInteger index = [self indexForParser : feedParser];
   feedDataTmp[index] = nil;

   if (!feedData[index].count)//feedData[index] is either nil or an empty array.
      CernAPP::ShowErrorHUD(auxParentViews[index - 1], @"Network error");
   else
      CernAPP::ShowErrorAlert(@"Please, check network!", @"Close");
   
   if ([self allParsersFinished])
      self.navigationItem.rightBarButtonItem.enabled = YES;
   
}

//________________________________________________________________________________________
- (void) feedParserDidFinish : (MWFeedParser *) feedParser
{
   assert(feedParser != nil && "feedParserDidFinish:, parameter 'feedParser' is nil");
   
   //Stop the corresponding spinner and update the corresponding collection view.
   NSMutableArray *data = nil;
   NSUInteger feedN = 0;
   for (NSUInteger i = 0; i < 3; ++i) {
      if (feedParser == parsers[i]) {
         feedN = i;
         data = feedDataTmp[i];
         feedDataTmp[i] = nil;
         break;
      }
   }
   
   assert(data != nil && "feedParserDidFinish:, unknown parser");
   
   feedData[feedN] = data;

   //TODO: remove, this is for the test only.
   [self hideSpinnerForView : feedN];
   
   if ([self allParsersFinished])
      self.navigationItem.rightBarButtonItem.enabled = YES;

   /*
   NSLog(@" --------- got a feed:");

   for (MWFeedItem *item in data) {
      NSLog(@"title: %@", item.title);
      NSLog(@"description: %@", item.description);
      NSLog(@"link: %@", item.link);
      NSLog(@"date: %@", item.date);
      NSLog(@"updated: %@", item.updated);
      NSLog(@"summary: %@", item.summary);
      NSLog(@"content: %@", item.content);
      NSLog(@"enclosures: %@", item.enclosures);
   }
      
   NSLog(@"end of feed ---------- ");
   */

   if (!feedN)
      [self.collectionView reloadData];
   else
      [auxCollectionViews[feedN - 1] reloadData];
   //
}

//________________________________________________________________________________________
- (void) startParsing : (BOOL) selectedSegmentOnly
{
   if (selectedSegmentOnly) {
      const NSInteger selected = segmentedControl.selectedSegmentIndex;
      assert(parsers[selected] != nil &&
             "startParsing:, parser for selected segment is nil");
      [parsers[selected] parse];
      feedDataTmp[selected] = [[NSMutableArray alloc] init];
   } else {
      assert(parsers[0] != nil && parsers[1] != nil && parsers[2] != nil &&
             "startParsing:, not all parsers/feeds are valid");
      //assert on the parsing been stopped?
      for (unsigned i = 0; i < 3; ++i) {
         feedDataTmp[i] = [[NSMutableArray alloc] init];
         [parsers[i] parse];
      }
   }
}

//________________________________________________________________________________________
- (void) stopParsing : (BOOL) selectedSegmentOnly
{
   if (selectedSegmentOnly) {
      const NSInteger selected = segmentedControl.selectedSegmentIndex;
      assert(parsers[selected] != nil &&
             "stopParsing:, parser for selected segment is nil");
      [parsers[selected] stopParsing];
   } else {
      assert(parsers[0] != nil && parsers[1] != nil && parsers[2] != nil &&
             "stopParsing:, not all parsers/feeds are valid");
      //assert on the parsing been stopped?
      for (unsigned i = 0; i < 3; ++i)
         [parsers[i] stopParsing];
   }
}

#pragma mark - UIViewCollectionDataSource

//________________________________________________________________________________________
- (NSInteger) indexForCollectionView : (UICollectionView *) aCollectionView
{
   assert(aCollectionView != nil && "indexForCollectionView:, parameter 'aCollectionView' is nil");

   if (aCollectionView == self.collectionView)
      return 0;
   
   for (unsigned i = 0; i < 2; ++i) {
      if (auxCollectionViews[i] == aCollectionView)
         return i + 1;
   }
   
   assert(0 && "indexForCollectionView:, collection view not found");
   
   return 0;
}

//________________________________________________________________________________________
- (NSInteger) numberOfSectionsInCollectionView : (UICollectionView *) aCollectionView
{
   assert(aCollectionView != nil && "numberOfSectionsInCollectionView, parameter 'aCollectionView' is nil");

   const NSUInteger viewIndex = [self indexForCollectionView : aCollectionView];
   if (feedData[viewIndex].count)//If feedData[viewIndex] is nil, condition is false.
      return 1;

   return 0;
}

//________________________________________________________________________________________
- (NSInteger) collectionView : (UICollectionView *) aCollectionView numberOfItemsInSection : (NSInteger) section
{
   assert(aCollectionView != nil && "collectionView:numberOfItemsInSection:, parameter 'aCollectionView' is nil");
   assert(section == 0 && "collectionView:numberOfItemsInSection:, parameter 'section' is out of bounds");
   
   const NSUInteger viewIndex = [self indexForCollectionView : aCollectionView];
   return feedData[viewIndex].count;//0 if feedData[viewIndex] is nil.
}


//________________________________________________________________________________________
- (UICollectionViewCell *) collectionView : (UICollectionView *) aCollectionView cellForItemAtIndexPath : (NSIndexPath *) indexPath
{
   assert(aCollectionView != nil && "collectionView:cellForItemAtIndexPath:, parameter 'aCollectionView' is nil");
   assert(indexPath != nil && "collectionView:cellForItemAtIndexPath:, parameter 'indexPath' is nil");
   assert(indexPath.section == 0 && "collectionView:cellForItemAtIndexPath:, section index is out of bounds");

   UICollectionViewCell *cell = [aCollectionView dequeueReusableCellWithReuseIdentifier : @"WebcastViewCell" forIndexPath : indexPath];
   assert(!cell || [cell isKindOfClass : [WebcastViewCell class]] &&
          "collectionView:cellForItemAtIndexPath:, reusable cell has a wrong type");
   if (!cell)
      cell = [[WebcastViewCell alloc] initWithFrame : CGRect()];
   
   WebcastViewCell * const webcastCell = (WebcastViewCell *)cell;
   
   const NSUInteger i = [self indexForCollectionView : aCollectionView];
   NSArray * const data = feedData[i];
   assert(indexPath.row >= 0 && indexPath.row < data.count &&
          "collectionView:cellForItemAtIndexPath:, row index is out of bounds");
   MWFeedItem * const feedItem = (MWFeedItem *)data[indexPath.row];
   [webcastCell setCellData : feedItem];

   //Check if we have a thumbnail and download it if not.
   if (!feedItem.image) {
      //image downloader.
      NSMutableDictionary * const downloaders = imageDownloaders[i];
      assert(downloaders != nil &&
             "collectionView:cellForItemAtIndexPath:, imageDownloaders is not initialized correctly");
      
      if (!downloaders[indexPath]) {
         if (feedItem.summary) {//TODO: verify and confirm where do we have a thumbnail link.
            if (NSString * const urlString = [NewsTableViewController firstImageURLFromHTMLString : feedItem.summary]) {
               //We need this key to later be able identify a collection view, and indexPath.seciton is always 0 here, since
               //all 3 our views have 1 section.
               NSIndexPath * const newKey = [NSIndexPath indexPathForRow : indexPath.row inSection : NSInteger(i)];
               ImageDownloader * const newDownloader = [[ImageDownloader alloc] initWithURLString : urlString];
               [downloaders setObject : newDownloader forKey : newKey];
               newDownloader.indexPathInTableView = newKey;
               newDownloader.delegate = self;
               [newDownloader startDownload];
            }
         }
      }
   }

   return webcastCell;
}

#pragma mark - UICollectionViewFlowLayout delegate.

//________________________________________________________________________________________
- (CGSize) collectionView : (UICollectionView *) collectionView layout : (UICollectionViewLayout*) collectionViewLayout
           sizeForItemAtIndexPath : (NSIndexPath *) indexPath
{
#pragma unused(collectionView, collectionViewLayout, indexPath)
   return CGSizeMake(230.f, 230.f);
}

#pragma mark - Thumbnails download.

//________________________________________________________________________________________
- (void) imageDidLoad : (NSIndexPath *) indexPath
{
   assert(indexPath != nil && "imageDidLoad:, parameter 'indexPath' is nil");
   assert(indexPath.section >= 0 && indexPath.section < 3 &&
          "imageDidLoad:, section index is out of bounds");
   
   ImageDownloader * const downloader = imageDownloaders[indexPath.section][indexPath];
   assert(downloader != nil && "imageDidLoad:, downloader not found for index path");
   
   if (downloader.image) {
      NSArray * const data = feedData[indexPath.section];
      assert(indexPath.row >= 0 && indexPath.row < data.count &&
             "imageDidLoad:, row index is out of bounds");
      MWFeedItem * const feedItem = (MWFeedItem *)data[indexPath.row];
      feedItem.image = downloader.image;
      
      UICollectionView * const viewToUpdate = indexPath.section ? auxCollectionViews[indexPath.section - 1] : self.collectionView;
      [viewToUpdate reloadItemsAtIndexPaths : @[[NSIndexPath indexPathForRow : indexPath.row inSection : 0]]];
   }
   
   [imageDownloaders[indexPath.section] removeObjectForKey : indexPath];
   //Probably (later) hide a spinner here.
}

//________________________________________________________________________________________
- (void) imageDownloadFailed : (NSIndexPath *) indexPath
{
   assert(indexPath != nil && "imageDownloadFailed:, parameter 'indexPath' is nil");
   assert(indexPath.section >= 0 && indexPath.section < 3 &&
          "imageDownloadFailed:, section index is out of bounds");
   
   assert(imageDownloaders[indexPath.section][indexPath] &&
          "imageDownloadFailed:, no downloader found for indexPath");
   
   [imageDownloaders[indexPath.section] removeObjectForKey : indexPath];
   
   //Probably (later) hide a spinner here.
}

#pragma mark - Interface orientation.

//________________________________________________________________________________________
- (BOOL) shouldAutorotate
{
   return YES;
}

#pragma mark - UI.

//________________________________________________________________________________________
- (IBAction) sectionSelected : (UISegmentedControl *) sender
{
   assert(sender != nil && "sectionSelected:, parameter 'sender' is nil");
   
   const NSInteger i = sender.selectedSegmentIndex;
   assert(i >= 0 && i < 3 && "sectionSelected:, invalid segment index");
   
   if (!i)
      [self.view bringSubviewToFront : self.collectionView];
   else
      [self.view bringSubviewToFront : auxParentViews[i - 1]];
}

//________________________________________________________________________________________
- (IBAction) revealMenu : (id) sender
{
#pragma unused(sender)
   [self.slidingViewController anchorTopViewTo : ECRight];
}

//________________________________________________________________________________________
- (IBAction) reload : (id) sender
{
   if (![self hasConnection])
      CernAPP::ShowErrorAlert(@"Please, check network!", @"Close");
   else
      [self refresh : YES];//We refresh only a visible page!
}

//________________________________________________________________________________________
- (void) showSpinners : (BOOL) selectedSegmentOnly
{
   if (selectedSegmentOnly) {
      const NSInteger selected = segmentedControl.selectedSegmentIndex;
      assert(selected >= 0 && selected < 3 && "showSpinners, invalid segment index");
      CernAPP::ShowSpinner(spinners[selected]);
   } else {
      for (unsigned i = 0; i < 3; ++i)
         CernAPP::ShowSpinner(spinners[i]);
   }
}

//________________________________________________________________________________________
- (void) hideSpinnerForView : (NSUInteger) viewIndex
{
   assert(viewIndex < 3 && "hideSpinnerForView:, parameter 'viewIndex' is out of bounds");
   
   CernAPP::HideSpinner(spinners[viewIndex]);
}

#pragma mark - ConnectionController

//________________________________________________________________________________________
- (void) cancelAllDownloaders : (BOOL) selectedSegmentOnly
{
   if (selectedSegmentOnly) {
      const NSInteger segment = segmentedControl.selectedSegmentIndex;
      assert(segment >= 0 && segment < 3 && "cancelAllDownloaders:, selected index is out of bounds");
      
      for (ImageDownloader *downloader in imageDownloaders[segment])
         [downloader cancelDownload];
      
      [imageDownloaders[segment] removeAllObjects];
   } else {
      for (unsigned i = 0; i < 3; ++i) {
         for (ImageDownloader *downloader in imageDownloaders[i])
            [downloader cancelDownload];
      
         [imageDownloaders[i] removeAllObjects];
      }
   }
}

//________________________________________________________________________________________
- (void) cancelAnyConnections
{
   for (unsigned i = 0; i < 3; ++i) {
      [parsers[i] stopParsing];
      feedDataTmp[i] = nil;
   }
   
   [self cancelAllDownloaders : NO];
}

@end
