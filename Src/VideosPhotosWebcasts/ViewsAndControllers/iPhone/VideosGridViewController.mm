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
#import "MBProgressHUD.h"
#import "Reachability.h"
#import "GUIHelpers.h"

@implementation VideosGridViewController {
   MBProgressHUD *noConnectionHUD;
   BOOL loaded;
   
   //
   NSOperationQueue *parserQueue;
   VideoCollectionsParserOperation *operation;
   
   Reachability *internetReach;
   UIActivityIndicatorView *spinner;
}

@synthesize spinner, noConnectionHUD;

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
      videoThumbnails = [NSMutableDictionary dictionary];

      parserQueue = [[NSOperationQueue alloc] init];
      operation = nil;
      
      loaded = NO;
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
   
   [self.collectionView registerClass : [VideoThumbnailCell class] forCellWithReuseIdentifier : @"VideoThumbnailCell"];
   
   [self.collectionView registerClass : [CollectionSupplementraryView class]
    forSupplementaryViewOfKind : UICollectionElementKindSectionHeader
    withReuseIdentifier : [CollectionSupplementraryView reuseIdentifierHeader]];
   [self.collectionView registerClass : [CollectionSupplementraryView class]
    forSupplementaryViewOfKind : UICollectionElementKindSectionFooter
     withReuseIdentifier : [CollectionSupplementraryView reuseIdentifierFooter]];
}

//________________________________________________________________________________________
- (void) viewWillAppear : (BOOL) animated
{
   if (!loaded) {
      [self refresh];
      loaded = YES;
   }
}

#pragma mark - Refresh logic.

//________________________________________________________________________________________
- (void) startParserOperation
{
   assert(parserQueue != nil && "startParserOperation, parserQueue is nil");
   assert(operation == nil && "startParserOperation, called while parser operation is active");
   
   operation = [[VideoCollectionsParserOperation alloc] initWithURLString : @"http://cdsweb.cern.ch/search?ln=en&cc=Press+Office+Video+Selection&p"
                                                                             "=internalnote%3A%22ATLAS%22&f=&action_search=Search&c=Press+Office+V"
                                                                             "ideo+Selection&c=&sf=year&so=d&rm=&rg=100&sc=0&of=xm"
                                                            resourceTypes : @[@"mp40600", @"jpgposterframe"]];
   operation.delegate = self;
   [parserQueue addOperation : operation];
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
   
   self.navigationItem.rightBarButtonItem.enabled = NO;
 
   [noConnectionHUD hide : YES];
   CernAPP::ShowSpinner(self);
   
   [self startParserOperation];
}

#pragma mark - Parser operation delegate.

//________________________________________________________________________________________
- (void) parserDidFailWithError : (NSError *) error
{
#pragma unused(error)

   CernAPP::HideSpinner(self);
   CernAPP::ShowErrorHUD(self, @"Network error");

   [parserQueue cancelAllOperations];
   operation = nil;
   //Refresh button.
   self.navigationItem.rightBarButtonItem.enabled = YES;
}

//________________________________________________________________________________________
- (void) parserDidFinishWithItems:(NSArray *)items
{
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
   for (NSDictionary *metaData in videoMetadata) {
      ImageDownloader * const downloader = [[ImageDownloader alloc] initWithURL : (NSURL *)metaData[@"jpgposterframe"]];
      NSIndexPath * const indexPath = [NSIndexPath indexPathForRow : 0 inSection : section];
      downloader.indexPathInTableView = indexPath;
      downloader.delegate = self;
      [imageDownloaders setObject : downloader forKey : indexPath];
      [downloader startDownload];
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

   UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier : @"VideoThumbnailCell" forIndexPath : indexPath];
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
      view.descriptionLabel.text = (NSString *)metaData[@"title"];
      UIFont * const font = [UIFont fontWithName : CernAPP::childMenuFontName size : 12.f];
      assert(font != nil && "collectionView:viewForSupplementaryElementOfKinf:atIndexPath:, font not found");
      view.descriptionLabel.font = font;
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
   NSURL * const url = (NSURL *)video[@"mp40600"];
   
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
   [parserQueue cancelAllOperations];
   operation = nil;
   [self cancelAllDownloaders];
}

#pragma mark - Sliding view.

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
