//
//  VideosGridViewController.m
//  CERN App
//
//  Created by Eamon Ford on 8/9/12.
//  Copyright (c) 2012 CERN. All rights reserved.
//

#import <MediaPlayer/MediaPlayer.h>

#import "VideosGridViewController.h"
#import "ECSlidingViewController.h"
#import "PhotoGridViewCell.h"
#import "PhotoSetInfoView.h"
#import "MBProgressHUD.h"
#import "GUIHelpers.h"

@implementation VideosGridViewController {
   MBProgressHUD *noConnectionHUD;
   BOOL loaded;
   
   CernMediaMARCParser *parser;
   NSMutableArray *videoMetadata;
   NSMutableDictionary *videoThumbnails;
   NSMutableDictionary *imageDownloaders;
}

//________________________________________________________________________________________
- (id) initWithCoder : (NSCoder *) aDecoder
{
   if (self = [super initWithCoder : aDecoder]) {
      videoMetadata = [NSMutableArray array];
      videoThumbnails = [NSMutableDictionary dictionary];

      parser = [[CernMediaMARCParser alloc] init];
      parser.url = [NSURL URLWithString : @"http://cdsweb.cern.ch/search?ln=en&cc=Press+Office+Video+Selection&p=internalnote%3A%22ATLAS%22&f=&action_search=Search&c=Press+Office+Video+Selection&c=&sf=year&so=d&rm=&rg=100&sc=0&of=xm"];
      parser.resourceTypes = @[@"mp40600", @"jpgposterframe"];
      parser.delegate = self;

      loaded = NO;
   }
   
   return self;
}

//________________________________________________________________________________________
- (void) viewWillAppear : (BOOL) animated
{
   if (!loaded) {
      [self refresh];
      loaded = YES;
   }
}

//________________________________________________________________________________________
- (IBAction) refresh : (id) sender
{
#pragma unused(sender)

   [self refresh];
}

//________________________________________________________________________________________
- (void) refresh
{
   assert(parser.isFinishedParsing == YES && "refresh, called while parser is active");

   self.navigationItem.rightBarButtonItem.enabled = NO;
   videoMetadata = [[NSMutableArray alloc] init];
   videoThumbnails = [[NSMutableDictionary alloc] init];
   
   [self.collectionView reloadData];
   
   [noConnectionHUD hide : YES];
   [parser parse];
   [MBProgressHUD showHUDAddedTo : self.view animated : YES];
}

//________________________________________________________________________________________
- (void) viewDidLoad
{
   [super viewDidLoad];
}

//________________________________________________________________________________________
- (void) hudWasTapped : (MBProgressHUD *) hud
{
   [self refresh];
}

#pragma mark - CernMediaMARCParserDeleate methods

//________________________________________________________________________________________
- (void) parserDidFinish : (CernMediaMARCParser *) parser
{
   [MBProgressHUD hideHUDForView : self.view animated : YES];
   [self downloadVideoThumbnails];
   [self.collectionView reloadData];
   self.navigationItem.rightBarButtonItem.enabled = YES;
}

//________________________________________________________________________________________
- (void) parser : (CernMediaMARCParser *) parser didParseRecord : (NSDictionary *) record
{
   // Copy over just the title, the date, and the first url of each resource type
   NSMutableDictionary * const video = [NSMutableDictionary dictionary];
   [video setObject : record[@"title"] forKey : @"title"];
   NSDate * const date = (NSDate *)record[@"date"];
   if (date)
      [video setObject : date forKey : @"VideoMetadataPropertyDate"];

   NSDictionary * const resources = (NSDictionary *)record[@"resources"];
   NSArray *resourceTypes = [resources allKeys];
   for (NSString *currentResourceType in resourceTypes) {
      NSURL * const url = [resources[currentResourceType] objectAtIndex : 0];
      [video setObject : url forKey : currentResourceType];
   }
   
   [videoMetadata addObject : video];
}

//________________________________________________________________________________________
- (void) parser : (CernMediaMARCParser *) parser didFailWithError : (NSError *) error
{
   //TODO: report/handle errors correctly.
   
   [MBProgressHUD hideAllHUDsForView : self.view animated : YES];
   noConnectionHUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
   noConnectionHUD.delegate = self;
   noConnectionHUD.mode = MBProgressHUDModeText;
   noConnectionHUD.labelText = @"No internet connection";
   noConnectionHUD.removeFromSuperViewOnHide = YES;
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

   UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier : @"VideoCell" forIndexPath : indexPath];
   assert(!cell || [cell isKindOfClass : [PhotoGridViewCell class]] &&
          "collectionView:cellForItemAtIndexPath:, reusable cell has a wrong type");
   
   if (!cell)
      cell = [[PhotoGridViewCell alloc] initWithFrame : CGRect()];
   
   PhotoGridViewCell * const photoCell = (PhotoGridViewCell *)cell;
   
   assert(indexPath.section >= 0 && indexPath.section < videoMetadata.count &&
          "collectionView:cellForItemAtIndexPath:, section is out of bounds");
   assert(indexPath.row == 0 && "collectionView:cellForItemAtIndexPath:, row is out of bounds");

   if (UIImage * const thumbnail = (UIImage *)videoThumbnails[indexPath])
      photoCell.imageView.image = thumbnail;
   
   return photoCell;
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

   UICollectionReusableView *view = nil;
   if ([kind isEqualToString : UICollectionElementKindSectionHeader]) {
      view = [collectionView dequeueReusableSupplementaryViewOfKind : kind
                             withReuseIdentifier : @"VideoInfoView" forIndexPath : indexPath];

      assert(!view || [view isKindOfClass : [PhotoSetInfoView class]] &&
             "collectionView:viewForSupplementaryElementOfKinf:atIndexPath:, reusable view has a wrong type");
      
      if (!view)
         view = [[PhotoSetInfoView alloc] initWithFrame : CGRect()];

      PhotoSetInfoView * const infoView = (PhotoSetInfoView *)view;
      
      NSDictionary * const metaData = (NSDictionary *)videoMetadata[indexPath.section];
      
      
      infoView.descriptionLabel.text = (NSString *)metaData[@"title"];
      
      UIFont * const font = [UIFont fontWithName : CernAPP::childMenuFontName size : 12.f];
      assert(font != nil && "collectionView:viewForSupplementaryElementOfKinf:atIndexPath:, font not found");
      infoView.descriptionLabel.font = font;
   } else {
      //Footer.
      view = [collectionView dequeueReusableSupplementaryViewOfKind : kind
                             withReuseIdentifier : @"VideoCellFooter" forIndexPath : indexPath];

      assert(!view || [view isKindOfClass : [PhotoSetInfoView class]] &&
             "collectionView:viewForSupplementaryElementOfKinf:atIndexPath:, reusable view has a wrong type");
   }
   
   return view;
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
   MPMoviePlayerViewController *playerController = [[MPMoviePlayerViewController alloc] initWithContentURL : url];
   [self presentMoviePlayerViewControllerAnimated : (MPMoviePlayerViewController *)playerController];
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
   if (!parser.isFinishedParsing)
      [parser stop];
   
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

//________________________________________________________________________________________
- (NSUInteger) supportedInterfaceOrientations
{
   return  UIInterfaceOrientationMaskPortrait;
}

@end
