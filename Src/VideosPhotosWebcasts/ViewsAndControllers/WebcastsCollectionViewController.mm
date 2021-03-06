#import <cassert>

#import <MediaPlayer/MediaPlayer.h>

#import "WebcastsCollectionViewController.h"
#import "ECSlidingViewController.h"
#import "HUDRefreshProtocol.h"
#import "MenuViewController.h"
#import "VideoThumbnailCell.h"
#import "ApplicationErrors.h"
#import "MBProgressHUD.h"
#import "Reachability.h"
#import "DeviceCheck.h"
#import "AppDelegate.h"
#import "URLHelpers.h"

using CernAPP::NetworkStatus;

//________________________________________________________________________________________
@implementation WebcastsCollectionViewController {   
   IBOutlet UISegmentedControl *segmentedControl;
   
   //Now I need 3 parsers for 3 different feeds (it's possible that user switched between the
   //different segments and thus all of them are loading now.
   MWFeedParser *parsers[3];
   NSMutableArray *feedData;
   NSMutableArray *feedDataTmp[3];
   NSMutableDictionary *imageDownloaders[3];

   BOOL viewDidAppear;
   
   //These are additional collection views for the upcoming and recorded webcasts.
   UIView *auxParentViews[2];
   UICollectionView * auxCollectionViews[2];
   
   UIActivityIndicatorView *spinners[3];
   MBProgressHUD *noConnectionHUDs[3];
   MBProgressHUD *noWebcastsHUDs[3];

   Reachability *internetReach;
}

@synthesize apnID, apnItems;

#pragma mark - Reachability.

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
      [self resetFeedData : NO];//NO == reset all, "not only selected".
      
      for (unsigned i = 0; i < 3; ++i) {
         parsers[i] = nil;
         feedDataTmp[i] = nil;
         
         imageDownloaders[i] = [[NSMutableDictionary alloc] init];
         
         spinners[i] = nil;
         noConnectionHUDs[i] = nil;
         noWebcastsHUDs[i] = nil;
      }

      for (unsigned i = 0; i < 2; ++i) {
         auxParentViews[i] = nil;
         auxCollectionViews[i] = nil;
      }

      viewDidAppear = NO;
      internetReach = [Reachability reachabilityForInternetConnection];
      
      apnID = 0;
      apnItems = 0;
   }
   
   return self;
}

//________________________________________________________________________________________
- (void) dealloc
{
   [self cancelAnyConnections];
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
      
      [auxCollectionViews[i] registerClass : [VideoThumbnailCell class]
           forCellWithReuseIdentifier : [VideoThumbnailCell cellReuseIdentifier]];
      
      spinners[i + 1] = CernAPP::AddSpinner(auxParentViews[i]);
      CernAPP::HideSpinner(spinners[i + 1]);
   }

   [self.collectionView registerClass : [VideoThumbnailCell class]
           forCellWithReuseIdentifier : [VideoThumbnailCell cellReuseIdentifier]];

   spinners[0] = CernAPP::AddSpinner(self.view);
   CernAPP::HideSpinner(spinners[0]);
}

//________________________________________________________________________________________
- (void) viewWillAppear : (BOOL) animated
{
   CGRect frame = self.collectionView.frame;
   auxParentViews[0].frame = frame;
   auxParentViews[1].frame = frame;
   
   frame.origin = CGPoint();
   auxCollectionViews[0].frame = frame;
   auxCollectionViews[1].frame = frame;

   if (!viewDidAppear) {
      //Do it only once.
      [segmentedControl setSelectedSegmentIndex : 0];
      [self.view bringSubviewToFront : self.collectionView];
   }

   if (CernAPP::SystemVersionGreaterThanOrEqualTo(@"7.0")) {
      UIEdgeInsets insets = {};
      insets.top = self.navigationController.navigationBar.frame.size.height + 20.f;
      auxCollectionViews[0].contentInset = insets;
      auxCollectionViews[1].contentInset = insets;
   }
}

#pragma mark - feedData management.

//________________________________________________________________________________________
- (void) resetFeedData : (BOOL) selectedOnly
{
   if (!selectedOnly) {
      feedData = [[NSMutableArray alloc] initWithArray : @[[NSNull null],
                                                              [NSNull null],
                                                              [NSNull null]]];
   } else {
      assert(segmentedControl != nil && "resetFeedData:, segmented control is nil");
      const NSInteger selected = segmentedControl.selectedSegmentIndex;
      feedData[selected] = [NSNull null];
   }
}

//________________________________________________________________________________________
- (NSString *) cacheID
{
   assert(apnID > 0 && "cacheID, ivalid apnID");
   
   return [NSString stringWithFormat : @"%lu", (unsigned long)apnID];
}

//________________________________________________________________________________________
- (BOOL) emptyData
{
   for (NSObject * obj in feedData) {
      if (obj != [NSNull null] && ((NSArray *)obj).count)
         return NO;
   }
   
   return YES;
}

//________________________________________________________________________________________
- (BOOL) emptyData : (NSUInteger) index
{
   assert(index < 3 && "emptyData:, parameter 'index' is out of bounds");
   
   return feedData[index] == [NSNull null] || !((NSArray *)feedData[index]).count;
}

//________________________________________________________________________________________
- (void) writeAppCache
{
   assert([self emptyData] == NO && "writeAppCache, invalid cache");
   assert([(AppDelegate *)[UIApplication sharedApplication].delegate isKindOfClass : [AppDelegate class]] &&
          "writeAppCache, app delegate is either nil or has a wrong type");
   
   [(AppDelegate *)[UIApplication sharedApplication].delegate cacheData : feedData withKey : self.cacheID];
}

//________________________________________________________________________________________
- (BOOL) initFromAppCache
{
   assert([(AppDelegate *)[UIApplication sharedApplication].delegate isKindOfClass : [AppDelegate class]] &&
          "initFromAppCache, app delegate is either nil or has a wrong type");
   AppDelegate * const appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
   
   if ((feedData = (NSMutableArray *)[appDelegate cacheForKey : [self cacheID]])) {
      if (![self emptyData]) {
         self.navigationItem.rightBarButtonItem.enabled = YES;
         for (NSUInteger i = 0; i < 3; ++i)
            [self downloadThumbnailsForPage : i];
         
         if (![self emptyData : 0]) {
            [self downloadThumbnailsForPage : 0];
            [self.collectionView reloadData];
         } else
            CernAPP::ShowInfoHUD(self.collectionView, @"No webcasts in this category at the moment");

         for (NSUInteger i = 0; i < 2; ++i) {
            if (![self emptyData : i + 1]) {
               [self downloadThumbnailsForPage : i + 1];
               [auxCollectionViews[i] reloadData];
            } else
               CernAPP::ShowInfoHUD(auxCollectionViews[i], @"No webcasts in this category at the moment");
         }
         
         return YES;
      }
   } else
      [self resetFeedData : NO];//NO == all segments.

   return NO;
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
      if (![self initFromAppCache])
         [self refresh : NO];
   }
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
      
      if ([name isEqualToString:@"Live"]) {
         parsers[0] = [[MWFeedParser alloc] initWithFeedURL : [NSURL URLWithString : urlStr]];
         parsers[0].atomSpecialCase = YES;//TODO: MWFeedParser is not able to find a link.
      } else if ([name isEqualToString : @"Upcoming"]) {
         parsers[1] = [[MWFeedParser alloc] initWithFeedURL : [NSURL URLWithString : urlStr]];
         parsers[1].atomSpecialCase = YES;
      } else if ([name isEqualToString : @"Recent"])
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

   assert(auxCollectionViews[0] != nil && auxCollectionViews[1] != nil &&
          "refresh:, aux. collection views were not initialized correctly");

   if (!selectedSegmentOnly) {
      [MBProgressHUD hideAllHUDsForView : self.collectionView animated : NO];
      [MBProgressHUD hideAllHUDsForView : auxCollectionViews[0] animated : NO];
      [MBProgressHUD hideAllHUDsForView : auxCollectionViews[1] animated : NO];

   } else {
      const NSInteger selected = segmentedControl.selectedSegmentIndex;
      if (!selected)
         [MBProgressHUD hideAllHUDsForView : self.collectionView animated : NO];
      else
         [MBProgressHUD hideAllHUDsForView : auxCollectionViews[selected - 1] animated : NO];
   }
   
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
   [self hideSpinnerForView : index];

   if (feedData[index] == [NSNull null] || !((NSArray *)feedData[index]).count)//feedData[index] is either nil or an empty array.
      CernAPP::ShowErrorHUD(!index ? self.collectionView : auxCollectionViews[index - 1], @"Network error");
   else
      CernAPP::ShowErrorAlert(@"Please, check network!", @"Close");
   
   if ([self allParsersFinished]) {
      if (![self emptyData])
         [self hideAPNHints];
      
      self.navigationItem.rightBarButtonItem.enabled = YES;
   }
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
   
   if ([self allParsersFinished]) {
      self.navigationItem.rightBarButtonItem.enabled = YES;
      if (![self emptyData])
         [self writeAppCache];

      [self hideAPNHints];//??
   }

   if (!feedN) {
      [self.collectionView reloadData];
      if (!((NSArray *)feedData[0]).count)
         CernAPP::ShowInfoHUD(self.collectionView, @"No webcasts in this category at the moment");
   } else {
      [auxCollectionViews[feedN - 1] reloadData];
      if (!((NSArray *)feedData[feedN]).count)
         CernAPP::ShowInfoHUD(auxCollectionViews[feedN - 1], @"No webcasts in this category at the moment");
   }

   [self downloadThumbnailsForPage : feedN];
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
   if (feedData[viewIndex] != [NSNull null] && ((NSArray *)feedData[viewIndex]).count)//If feedData[viewIndex] is nil, condition is false.
      return 1;

   return 0;
}

//________________________________________________________________________________________
- (NSInteger) collectionView : (UICollectionView *) aCollectionView numberOfItemsInSection : (NSInteger) section
{
   assert(aCollectionView != nil && "collectionView:numberOfItemsInSection:, parameter 'aCollectionView' is nil");
   assert(section == 0 && "collectionView:numberOfItemsInSection:, parameter 'section' is out of bounds");
   
   const NSUInteger viewIndex = [self indexForCollectionView : aCollectionView];
   
   if (feedData[viewIndex] == [NSNull null])
      return 0;
   
   return ((NSArray *)feedData[viewIndex]).count;
}


//________________________________________________________________________________________
- (UICollectionViewCell *) collectionView : (UICollectionView *) aCollectionView cellForItemAtIndexPath : (NSIndexPath *) indexPath
{
   assert(aCollectionView != nil && "collectionView:cellForItemAtIndexPath:, parameter 'aCollectionView' is nil");
   assert(indexPath != nil && "collectionView:cellForItemAtIndexPath:, parameter 'indexPath' is nil");
   assert(indexPath.section == 0 && "collectionView:cellForItemAtIndexPath:, section index is out of bounds");

   UICollectionViewCell *cell = [aCollectionView dequeueReusableCellWithReuseIdentifier : [VideoThumbnailCell cellReuseIdentifier] forIndexPath : indexPath];
   assert(!cell || [cell isKindOfClass : [VideoThumbnailCell class]] &&
          "collectionView:cellForItemAtIndexPath:, reusable cell has a wrong type");

   if (!cell)
      cell = [[VideoThumbnailCell alloc] initWithFrame : CGRect()];
   
   VideoThumbnailCell * const webcastCell = (VideoThumbnailCell *)cell;
   
   const NSUInteger i = [self indexForCollectionView : aCollectionView];
   NSArray * const data = feedData[i];
   assert(indexPath.row >= 0 && indexPath.row < data.count &&
          "collectionView:cellForItemAtIndexPath:, row index is out of bounds");
   MWFeedItem * const feedItem = (MWFeedItem *)data[indexPath.row];
   [webcastCell setCellData : feedItem];

   //Check if we have a thumbnail and download it if not.
   if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPhone && !feedItem.image) {
      //image downloader.
      NSMutableDictionary * const downloaders = imageDownloaders[i];
      assert(downloaders != nil &&
             "collectionView:cellForItemAtIndexPath:, imageDownloaders is not initialized correctly");
      
      if (!downloaders[indexPath]) {
         if (feedItem.summary) {//TODO: verify and confirm where do we have a thumbnail link.
            if (NSString *urlString = CernAPP::FindImageURLStringInHTMLString(feedItem.summary)) {
               if ([urlString hasPrefix : @"//"])
                  urlString = [@"http:" stringByAppendingString : urlString];
               //We need this key to later be able identify a collection view, and indexPath.seciton is always 0 here, since
               //all 3 our views have 1 section.
               if (NSURL * const url = [NSURL URLWithString : urlString]) {
                  NSIndexPath * const newKey = [NSIndexPath indexPathForRow : indexPath.row inSection : NSInteger(i)];
                  ImageDownloader * const newDownloader = [[ImageDownloader alloc] initWithURL : url];
                  [downloaders setObject : newDownloader forKey : newKey];
                  newDownloader.indexPathInTableView = newKey;
                  newDownloader.delegate = self;
                  [newDownloader startDownload];
               }
            }
         }
      }
   }

   return webcastCell;
}

#pragma mark - UICollectionView delegate.

//________________________________________________________________________________________
- (void) collectionView : (UICollectionView *) aCollectionView didSelectItemAtIndexPath : (NSIndexPath *) indexPath
{
   assert(aCollectionView != nil && "collectionView:didSelecteItemAtIndexPath:, parameter 'aCollectionView' is nil");
   assert(indexPath != nil && "collectionView:didSelecteItemAtIndexPath:, parameter 'idnexPath' is nil");

   const NSUInteger viewIndex = [self indexForCollectionView : aCollectionView];
   assert(indexPath.row >= 0 && indexPath.row < ((NSArray *)feedData[viewIndex]).count &&
          "collectionView:didSelecteItemAtIndexPath:, row index is out of bounds");
   
   MWFeedItem * const item = feedData[viewIndex][indexPath.row];
   if (viewIndex < 2) {
      //Live/upcoming webcast, open it in a Safari browser.
      if (item.link) {
         BOOL urlOpened = NO;
         //TODO: this is obviously a crappy solution with relative urls from webcasts feed :(
         if ([item.link hasPrefix : @"//"]) {
            //Relative urls in the 'upcoming' category, UIApplication, obviously, can not handle them.
            //-openURL supports 'http', 'https', 'file', 'mailto'
            NSString *fixedUrl = [@"http:" stringByAppendingString : item.link];
            urlOpened = [[UIApplication sharedApplication] openURL : [NSURL URLWithString : fixedUrl]];
            if (!urlOpened) {
               fixedUrl = [@"https:" stringByAppendingString : item.link];
               urlOpened = [[UIApplication sharedApplication] openURL : [NSURL URLWithString : fixedUrl]];
            }
         } else {
            urlOpened = [[UIApplication sharedApplication] openURL : [NSURL URLWithString : item.link]];
         }
         
         if (!urlOpened)
            CernAPP::ShowErrorAlert(@"Bad url", @"Close");
      }
   } else {
      //For the 'recent' we have 'enclosures':
      if (item.enclosures) {
         for (id data in item.enclosures) {
            if ([data isKindOfClass : [NSDictionary class]]) {
               NSDictionary * const dict = (NSDictionary *)data;
               if ([dict[@"url"] isKindOfClass : [NSString class]]) {
                  if (NSURL * const url = [NSURL URLWithString : (NSString *)dict[@"url"]]) {
                     //Hmm, I have to do this stupid Voodoo magic, otherwise, I have error messages
                     //from the Quartz about invalid context.
                     //Manu thanks to these guys: http://stackoverflow.com/questions/13203336/iphone-mpmovieplayerviewcontroller-cgcontext-errors
                     //I beleive, at some point, BeginImageContext/EndImageContext can be removed after
                     //Apple fixes the bug.
                     UIGraphicsBeginImageContext(CGSizeMake(1.f, 1.f));
                     MPMoviePlayerViewController * const playerController = [[MPMoviePlayerViewController alloc] initWithContentURL : url];
                     UIGraphicsEndImageContext();
                     
                     [self presentMoviePlayerViewControllerAnimated : playerController];
                  }
                  break;
               }
            }
         }
      }
   }
}

#pragma mark - UICollectionViewFlowLayout delegate.

//________________________________________________________________________________________
- (CGSize) collectionView : (UICollectionView *) collectionView layout : (UICollectionViewLayout*) collectionViewLayout
           sizeForItemAtIndexPath : (NSIndexPath *) indexPath
{
#pragma unused(collectionView, collectionViewLayout, indexPath)
   return CGSizeMake(230.f, 240.f);
}

#pragma mark - Thumbnails download.

//________________________________________________________________________________________
- (void) startThumbnailDownloadersForPage : (NSUInteger) pageIndex
{
   //This function should never be called directly (call downloadThumbnailsForPage: instead).
   assert(pageIndex < 3 && "startThumbnailDownloadersForPage:, parameter 'pageIndex' is out of bounds");
   assert(imageDownloaders[pageIndex] != nil &&
          "startThumbnailDownloadersForPage:, imageDownloaders was not initialized correctly");
   
   assert(imageDownloaders[pageIndex].count != 0 &&
          "startThumbnailDownloadersForPage: no downloaders found");
   @autoreleasepool {
      NSArray * const values = [imageDownloaders[pageIndex] allValues];
      for (ImageDownloader *downloader in values)
         [downloader startDownload];
   }
}

//________________________________________________________________________________________
- (void) downloadThumbnailsForPage : (NSUInteger) pageIndex
{
   //On iPhone we see at max 2-3 cells (on iPad all
   //cells usually visible),
   //so on a small screen it's too obvious, that image downloaders are lazy,
   //thus I skip the laziness.

   assert(pageIndex < 3 && "downloadThumbnailsForPage:, parameter 'pageIndex' is out of bounds");

   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
      return;
   
   if (feedData[pageIndex] == [NSNull null])
      return;

   assert(imageDownloaders[pageIndex] != nil &&
          "downloadThumbnailsForPage:, imageDownloaders was not initialized correctly");

   if (NSArray * const data = (NSArray *)feedData[pageIndex]) {
      for (NSInteger j = 0, e = data.count; j < e; ++j) {
         MWFeedItem * const feedItem = (MWFeedItem *)data[j];
         if (feedItem.image)
            continue;
         
         NSString *urlString = CernAPP::FindImageURLStringInHTMLString(feedItem.summary);
         if (!urlString)
            continue;

         if ([urlString hasPrefix : @"//"])//relative urls in the 'upcoming' feed.
            urlString = [@"http:" stringByAppendingString : urlString];
         
         NSIndexPath * const newKey = [NSIndexPath indexPathForRow : j inSection : NSInteger(pageIndex)];
         if (imageDownloaders[pageIndex][newKey])
            continue;

         NSURL * const url = [NSURL URLWithString : urlString];
         if (!url)
            continue;
         
         ImageDownloader * const newDownloader = [[ImageDownloader alloc] initWithURL : url];
         newDownloader.delegate = self;
         newDownloader.indexPathInTableView = newKey;
         [imageDownloaders[pageIndex] setObject : newDownloader forKey : newKey];
      }
   }
   
   if (imageDownloaders[pageIndex].count)
      [self startThumbnailDownloadersForPage : pageIndex];
}

//________________________________________________________________________________________
- (void) imageDidLoad : (NSIndexPath *) indexPath
{
   assert(indexPath != nil && "imageDidLoad:, parameter 'indexPath' is nil");
   assert(indexPath.section >= 0 && indexPath.section < 3 &&
          "imageDidLoad:, section index is out of bounds");
   
   ImageDownloader * const downloader = (ImageDownloader *)imageDownloaders[indexPath.section][indexPath];
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
}

#pragma mark - Interface orientation.

//________________________________________________________________________________________
- (BOOL) shouldAutorotate
{
   return UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPhone;
}

#pragma mark - UI.

//________________________________________________________________________________________
- (IBAction) sectionSelected : (UISegmentedControl *) sender
{
   assert(sender != nil && "sectionSelected:, parameter 'sender' is nil");
   
   const NSInteger i = sender.selectedSegmentIndex;
   assert(i >= 0 && i < 3 && "sectionSelected:, invalid segment index");
   
   if (!i) {
      [self.view bringSubviewToFront : self.collectionView];
      if (!spinners[0].isHidden)
         [spinners[0].superview bringSubviewToFront : spinners[0]];
   } else
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
- (void) cancelAllDownloadersForPage : (NSUInteger) pageIndex
{
   assert(pageIndex < 3 && "calncelAllDownloadersForPage:, parameter 'pageIndex' is out of bounds");
   
   if (imageDownloaders[pageIndex].count) {
      @autoreleasepool {
         NSArray * const values = [imageDownloaders[pageIndex] allValues];
         for (ImageDownloader *downloader in values)
            [downloader cancelDownload];
         
         [imageDownloaders[pageIndex] removeAllObjects];
      }
   }
}

//________________________________________________________________________________________
- (void) cancelAllDownloaders : (BOOL) selectedSegmentOnly
{
   if (selectedSegmentOnly) {
      const NSInteger segment = segmentedControl.selectedSegmentIndex;
      assert(segment >= 0 && segment < 3 && "cancelAllDownloaders:, selected index is out of bounds");
      
      [self cancelAllDownloadersForPage : segment];
   } else {
      for (unsigned i = 0; i < 3; ++i)
         [self cancelAllDownloadersForPage : i];
   }
}

//________________________________________________________________________________________
- (void) cancelAnyConnections
{
   for (unsigned i = 0; i < 3; ++i) {
      parsers[i].delegate = nil;//I do not want to receive didFinish message from the parser.
      [parsers[i] stopParsing];
      parsers[i] = nil;
      feedDataTmp[i] = nil;
   }

   [self cancelAllDownloaders : NO];
}

#pragma mark - APN hints.

//________________________________________________________________________________________
- (void) setApnItems : (NSUInteger) nItems
{
   if (nItems)
      apnItems = nItems;
   else if (viewDidAppear)
      [self hideAPNHints];
   else
      apnItems = 0;
}

//________________________________________________________________________________________
- (void) hideAPNHints
{
   //At the moment no hint view attached to controller's view, only in a menu item.
   if (!apnItems)
      return;
   
   assert([self.slidingViewController.underLeftViewController isKindOfClass : [MenuViewController class]] &&
          "hideAPNHints, underLeftViewController has a wrong type");
   MenuViewController * const mvc = (MenuViewController *)self.slidingViewController.underLeftViewController;

   [mvc removeNotifications : apnItems forID : apnID];
   apnItems = 0;

   //Do something else with self.view or a navigation bar here.
}

@end
