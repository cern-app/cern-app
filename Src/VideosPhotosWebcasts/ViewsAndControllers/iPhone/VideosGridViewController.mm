//
//  VideosGridViewController.m
//  CERN App
//
//  Created by Eamon Ford on 8/9/12.
//  Copyright (c) 2012 CERN. All rights reserved.
//

//Modified for CERN.app by Timur Pocheptsov.
//AQGridView controller was replaced by UICollectionViewController.

#import <MediaPlayer/MediaPlayer.h>

#import "CollectionSupplementraryView.h"
#import "VideosGridViewController.h"
#import "ECSlidingViewController.h"
#import "VideoThumbnailCell.h"
#import "ApplicationErrors.h"
#import "CDSVideosParser.h"
#import "MBProgressHUD.h"
#import "Reachability.h"
#import "DeviceCheck.h"
#import "GUIHelpers.h"

@implementation VideosGridViewController {
   BOOL loaded;
   //
   NSURLConnection *CDSconnection;
   NSMutableData *xmlData;
   //
   NSOperationQueue *parserQueue;
   CDSVideosParserOperation *operation;
   
   NSMutableSet *datafieldTags;
   NSMutableSet *subfieldCodes;

   Reachability *internetReach;
}

@synthesize noConnectionHUD, spinner;

#pragma mark - Reachability.

//________________________________________________________________________________________
- (BOOL) hasConnection
{
   return internetReach && [internetReach currentReachabilityStatus] != CernAPP::NetworkStatus::notReachable;
}

//________________________________________________________________________________________
- (id) initWithCoder : (NSCoder *) aDecoder
{
   if (self = [super initWithCoder : aDecoder]) {
      videoMetadata = [NSMutableArray array];

      videoThumbnails = nil;
      imageDownloaders = nil;

      loaded = NO;

      CDSconnection = nil;
      xmlData = nil;

      parserQueue = [[NSOperationQueue alloc] init];
      operation = nil;
      
      datafieldTags = [[NSMutableSet alloc] init];
      [datafieldTags addObject : CernAPP::CDStagMARC];
      [datafieldTags addObject : CernAPP::CDStagDate];
      [datafieldTags addObject : CernAPP::CDStagTitle];
      //[datafieldTags addObject : CernAPP::CDStagTitleAlt];
      
      subfieldCodes = [[NSMutableSet alloc] init];
      [subfieldCodes addObject : CernAPP::CDScodeContent];
      [subfieldCodes addObject : CernAPP::CDScodeURL];
      [subfieldCodes addObject : CernAPP::CDScodeDate];
      [subfieldCodes addObject : CernAPP::CDScodeTitle];
      
      internetReach = nil;
   }

   return self;
}

//________________________________________________________________________________________
- (void) viewDidLoad
{
   [super viewDidLoad];

   internetReach = [Reachability reachabilityForInternetConnection];

   CernAPP::AddSpinner(self);
   CernAPP::HideSpinner(self);
   
   [self.collectionView registerClass : [VideoThumbnailCell class]
    forCellWithReuseIdentifier : [VideoThumbnailCell cellReuseIdentifier]];
   [self.collectionView registerClass : [CollectionSupplementraryView class]
    forSupplementaryViewOfKind : UICollectionElementKindSectionHeader
    withReuseIdentifier : [CollectionSupplementraryView reuseIdentifierHeader]];
   [self.collectionView registerClass : [CollectionSupplementraryView class]
    forSupplementaryViewOfKind : UICollectionElementKindSectionFooter
    withReuseIdentifier : [CollectionSupplementraryView reuseIdentifierFooter]];
}

//________________________________________________________________________________________
- (void) viewDidAppear : (BOOL) animated
{
   [super viewDidAppear : animated];

   if (!loaded) {
      loaded = YES;
      [self refresh];
   }
}

#pragma mark - Refresh logic.

//________________________________________________________________________________________
- (void) startParserOperation
{
   assert(parserQueue != nil && "startParserOperation, parserQueue is nil");
   assert(operation == nil && "startParserOperation, called while parser operation is active");
   assert(CDSconnection == nil && "startParserOperation, called while connection is still active");
   
   NSString * const urlString =
   @"http://cdsweb.cern.ch/search?ln=en&cc=Press+Office+Video+Selection&p=internalnote%3A%22ATLAS%22&f=&action_search=Search&c=Press+Office+Video+Selection&c=&sf=year&so=d&rm=&rg=100&sc=0&of=xm";
   
   if (NSURL * const url = [NSURL URLWithString : urlString]) {
      if (NSURLRequest * const request = [NSURLRequest requestWithURL : url]) {
         xmlData = [[NSMutableData alloc] init];
         CDSconnection = [[NSURLConnection alloc] initWithRequest : request delegate : self];
         if (CDSconnection)
            return;
         xmlData = nil;
      }
   }
   
   [self handleNetworkError : nil];
}

//________________________________________________________________________________________
- (IBAction) refresh : (id) sender
{
#pragma unused(sender)

   if (![self hasConnection]) {
      CernAPP::ShowErrorAlert(@"Please, check network!", @"Close");
      return;
   }

   [self refresh];
}

//________________________________________________________________________________________
- (void) refresh
{
   assert(parserQueue != nil && "refresh, parserQueue is nil");
   assert(operation == nil && "refresh, called while parsing operation is active");
   assert(CDSconnection == nil && "refresh, called while CDS connection is still active");

   [self cancelAllDownloaders];
   self.navigationItem.rightBarButtonItem.enabled = NO;
 
   [noConnectionHUD hide : YES];
   CernAPP::ShowSpinner(self);
   
   [self startParserOperation];
}

#pragma mark - NSURLConnectionDataDelegate and related methods.

//________________________________________________________________________________________
- (void) handleNetworkError : (NSError *) error
{
#pragma unused(error)

   [self resetControls];

   if (!videoMetadata.count)
      CernAPP::ShowErrorHUD(self, @"Network error");
   else
      CernAPP::ShowErrorAlert(@"Please, check network!", @"Close");
}

//________________________________________________________________________________________
- (void) connection : (NSURLConnection *) connection didReceiveData : (NSData *) data
{
#pragma unused(connection)

   assert(data != nil && "connection:didReceiveData:, parameter 'data' is nil");
   assert(xmlData != nil && "connection:didReceiveData:, xmlData is nil");
   
   [xmlData appendData : data];
}

//________________________________________________________________________________________
- (void) connection : (NSURLConnection *) connection didFailWithError : (NSError *) error
{
#pragma unused(connection, error)
   xmlData = nil;
   [CDSconnection cancel];
   CDSconnection = nil;
   [self handleNetworkError : error];
}

//________________________________________________________________________________________
- (void) connectionDidFinishLoading : (NSURLConnection *) connection
{
   assert(xmlData != nil && "connectionDidFinishLoading:, xmlData is nil");
   assert(operation == nil && "connectionDidFinishLoading:, called while parsing operation is active");
   assert(parserQueue != nil && "connectionDidFinishLoading:, parserQueue is nil");
   
   CDSconnection = nil;

   if (xmlData.length) {
      operation = [[CDSVideosParserOperation alloc] initWithXMLData : xmlData
                                                    datafieldTags : datafieldTags
                                                    subfieldCodes : subfieldCodes];
      xmlData = nil;
      operation.delegate = self;
      [parserQueue addOperation : operation];
   } else {
      xmlData = nil;
      [self handleNetworkError : nil];
   }
}

#pragma mark - Parser operation delegate.

//________________________________________________________________________________________
- (void) parserDidFailWithError : (NSError *) error
{
#pragma unused(error)

   if (!operation)//Was cancelled.
      return;

   [parserQueue cancelAllOperations];
   operation = nil;
   
   [self resetControls];
   //I can not report this error to an user - it's something quite
   //special from XML parser. Just enable the 'refresh' button and hide
   //the activity indicator.
}

//________________________________________________________________________________________
- (void) parserDidFinishWithItems : (NSArray *) items
{
   if (!operation)//Was cancelled.
      return;

   operation = nil;
   videoMetadata = [items copy];

   [self downloadVideoThumbnails];
   [self.collectionView reloadData];
}

#pragma mark - ImageDownloader.

//________________________________________________________________________________________
- (void) downloadVideoThumbnails
{
   NSUInteger section = 0;
   imageDownloaders = [[NSMutableDictionary alloc] init];
   videoThumbnails = [NSMutableDictionary dictionary];

   for (NSDictionary *metaData in videoMetadata) {
      if (NSURL * const thumbnailURL = metaData[CernAPP::CDSvideoThubmnailURL]) {//What if we don't have a thumbnail at all?
         ImageDownloader * const downloader = [[ImageDownloader alloc] initWithURL : thumbnailURL];
         NSIndexPath * const indexPath = [NSIndexPath indexPathForRow : 0 inSection : section];
         downloader.indexPathInTableView = indexPath;
         downloader.delegate = self;
         [imageDownloaders setObject : downloader forKey : indexPath];
         [downloader startDownload];
      }
   
      ++section;
   }
}

//________________________________________________________________________________________
- (void) imageDidLoad : (NSIndexPath *) indexPath
{
   //
   assert(indexPath != nil && "imageDidLoad, parameter 'indexPath' is nil");

   assert(indexPath.row == 0 && "imageDidLoad:, row is out of bounds");
   assert(indexPath.section < videoMetadata.count && "imageDidLoad:, section is out of bounds");
   
   ImageDownloader * const downloader = (ImageDownloader *)imageDownloaders[indexPath];
   assert(downloader != nil && "imageDidLoad:, no downloader found for the given index path");
   
   if (downloader.image) {
      assert(videoThumbnails[indexPath] == nil && "imageDidLoad:, image was loaded already");
      [videoThumbnails setObject : downloader.image forKey : indexPath];
      [self.collectionView reloadItemsAtIndexPaths:@[indexPath]];//may be, simply set an image for image view?
   }

   [imageDownloaders removeObjectForKey : indexPath];
   
   if (!imageDownloaders.count) {
      CernAPP::HideSpinner(self);
      self.navigationItem.rightBarButtonItem.enabled = YES;
   }
}

//________________________________________________________________________________________
- (void) imageDownloadFailed : (NSIndexPath *) indexPath
{
   assert(indexPath != nil && "imageDownloadFailed:, parameter 'indexPath' is nil");

   //Even if download failed, index still must be valid.
   assert(indexPath.row == 0 && "imageDownloadFailed:, row is out of bounds");
   assert(indexPath.section < videoMetadata.count && "imageDownloadFailed:, section is out of bounds");

   assert(imageDownloaders[indexPath] != nil &&
          "imageDownloadFailed:, no downloader for the given path");
   
   [imageDownloaders removeObjectForKey : indexPath];
   //But no need to update the collectionView.

   if (!imageDownloaders.count) {
      CernAPP::HideSpinner(self);
      self.navigationItem.rightBarButtonItem.enabled = YES;
   }
}

#pragma mark - UICollectionViewDataSource.

//________________________________________________________________________________________
- (NSInteger) numberOfSectionsInCollectionView : (UICollectionView *) collectionView
{
#pragma unused(collectionView)
   return videoMetadata.count;
}

//________________________________________________________________________________________
- (NSInteger) collectionView : (UICollectionView *) collectionView numberOfItemsInSection : (NSInteger) section
{
#pragma unused(collectionView)
   assert(section >= 0 && section < videoMetadata.count &&
          "collectionView:numbefOfItemsInSection:, parameter 'section' is out of bounds");
   return 1;//We always have 1 cell in a section.
}

//________________________________________________________________________________________
- (UICollectionViewCell *) collectionView : (UICollectionView *) collectionView cellForItemAtIndexPath : (NSIndexPath *) indexPath
{
   assert(collectionView != nil && "collectionView:cellForItemAtIndexPath:, parameter 'collectionView' is nil");
   assert(indexPath != nil && "collectionView:cellForItemAtIndexPath:, parameter 'indexPath' is nil");

   UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier : [VideoThumbnailCell cellReuseIdentifier] forIndexPath : indexPath];
   assert([cell isKindOfClass : [VideoThumbnailCell class]] &&
          "collectionView:cellForItemAtIndexPath:, reusable cell has a wrong type");
   
   VideoThumbnailCell * const videoCell = (VideoThumbnailCell *)cell;

   assert(indexPath.section >= 0 && indexPath.section < videoMetadata.count &&
          "collectionView:cellForItemAtIndexPath:, section is out of bounds");
   assert(indexPath.row == 0 && "collectionView:cellForItemAtIndexPath:, row is out of bounds");

   if (UIImage * const thumbnail = (UIImage *)videoThumbnails[indexPath])
      videoCell.imageView.image = thumbnail;
   
   return videoCell;
}

//________________________________________________________________________________________
- (UILabel *) descriptionLabelForHeaderView : (CollectionSupplementraryView *) view
{
   UILabel *descriptionLabel = nil;
   if (!view.subviews.count) {
      descriptionLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.f, 0.f, 320.f, 53.f)];
      descriptionLabel.textColor = [UIColor whiteColor];
      descriptionLabel.backgroundColor = [UIColor clearColor];
      descriptionLabel.numberOfLines = 0;
      descriptionLabel.textAlignment = NSTextAlignmentCenter;
      [view addSubview : descriptionLabel];
   } else {
      for (UIView *v in view.subviews) {
         if ([v isKindOfClass : [UILabel class]]) {
            descriptionLabel = (UILabel *)v;
            break;
         }
      }
   }
   
   return descriptionLabel;
}

//________________________________________________________________________________________
- (UICollectionReusableView *) collectionView : (UICollectionView *) collectionView
                               viewForSupplementaryElementOfKind : (NSString *) kind atIndexPath : (NSIndexPath *) indexPath
{
   assert(collectionView != nil &&
          "collectionView:viewForSupplementaryElementOfKinf:atIndexPath:, parameter 'collectionView' is nil");
   assert(indexPath != nil &&
          "collectionView:viewForSupplementaryElementOfKinf:atIndexPath:, parameter 'indexPath' is nil");
   assert(indexPath.section < videoMetadata.count &&
         "collectionView:viewForSupplementaryElementOfKinf:atIndexPath:, section is out of bounds");

   CollectionSupplementraryView *view = nil;
   
   if ([kind isEqualToString : UICollectionElementKindSectionHeader]) {
      view = [collectionView dequeueReusableSupplementaryViewOfKind : kind
              withReuseIdentifier : [CollectionSupplementraryView reuseIdentifierHeader]
              forIndexPath : indexPath];
      NSDictionary * const metaData = (NSDictionary *)videoMetadata[indexPath.section];

      UILabel * const descriptionLabel = [self descriptionLabelForHeaderView : view];
      descriptionLabel.text = (NSString *)metaData[CernAPP::CDScodeTitle];
      UIFont * const font = [UIFont fontWithName : CernAPP::childMenuFontName size : 12.f];
      assert(font != nil && "collectionView:viewForSupplementaryElementOfKinf:atIndexPath:, font not found");
      descriptionLabel.font = font;
   } else {
      view = [collectionView dequeueReusableSupplementaryViewOfKind : kind
              withReuseIdentifier : [CollectionSupplementraryView reuseIdentifierFooter]
              forIndexPath : indexPath];
   }

   return view;
}

//________________________________________________________________________________________
- (CGSize) collectionView : (UICollectionView *) collectionView layout : (UICollectionViewLayout*) collectionViewLayout
           sizeForItemAtIndexPath : (NSIndexPath *) indexPath
{
#pragma unused(collectionView, collectionViewLayout, indexPath)
   return CGSizeMake(250.f, 200.f);
}

#pragma mark - UICollectionViewDelegate

//________________________________________________________________________________________
- (void) collectionView : (UICollectionView *) collectionView didSelectItemAtIndexPath : (NSIndexPath *) indexPath
{
#pragma unused(collectionView)

   assert(indexPath != nil && "collectionView:didSelectItemAtIndexPath:, parameter 'indexPath' is nil");
   assert(indexPath.section >= 0 && indexPath.section < videoMetadata.count &&
          "collectionView:didSelectItemAtIndexPath:, section is out of bounds");

   NSDictionary * const video = (NSDictionary *)videoMetadata[indexPath.section];
   NSURL * const url = (NSURL *)video[CernAPP::CDSvideoURL];
   
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

#pragma mark - Connection controller.

//________________________________________________________________________________________
- (void) cancelAllDownloaders
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
- (void) cancelAnyConnections
{
   if (CDSconnection)
      [CDSconnection cancel];

   CDSconnection = nil;
   [parserQueue cancelAllOperations];
   operation = nil;
   [self cancelAllDownloaders];
}

#pragma mark - Sliding view and UI.

//________________________________________________________________________________________
- (void) resetControls
{
   CernAPP::HideSpinner(self);
   self.navigationItem.rightBarButtonItem.enabled = YES;
}

//________________________________________________________________________________________
- (IBAction) revealMenu : (id) sender
{
#pragma unused(sender)
   [self.slidingViewController anchorTopViewTo : ECRight];
}

//________________________________________________________________________________________
- (BOOL) shouldAutorotate
{
   return NO;
}

@end
