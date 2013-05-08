//
//  WebcastsGridViewController.m
//  CERN App
//
//  Created by Eamon Ford on 8/16/12.
//  Copyright (c) 2012 CERN. All rights reserved.
//

#import <cassert>

#import <MediaPlayer/MediaPlayer.h>

#import "WebcastsGridViewController.h"
#import "ECSlidingViewController.h"
#import "PhotoGridViewCell.h"
#import "ApplicationErrors.h"
#import "PhotoSetInfoView.h"
#import "MBProgressHUD.h"
#import "Reachability.h"
#import "GUIHelpers.h"

//TODO: inherit web casts controller from videos grid view controller not to
//have all this ugly copy and paste everywhere.

@implementation WebcastsGridViewController {
   BOOL loaded;

   WebcastsParser *parser;

   Reachability *internetReach;
   
   NSMutableDictionary *videoThumbnails;
   NSMutableDictionary *imageDownloaders;//Thumbnail downloaders.
   
   NSMutableArray *webcasts;
}

@synthesize noConnectionHUD, spinner;

#pragma mark - Life cycle.

//________________________________________________________________________________________
- (id) initWithCoder : (NSCoder *) aDecoder
{
   if (self = [super initWithCoder : aDecoder]) {
      parser = [[WebcastsParser alloc] init];
      parser.delegate = self;
   }

   return self;
}

//________________________________________________________________________________________
- (void) viewDidLoad
{
   [super viewDidLoad];
   
   CernAPP::AddSpinner(self);
   CernAPP::HideSpinner(self);
   
   internetReach = [Reachability reachabilityForInternetConnection];
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

//________________________________________________________________________________________
- (void) didReceiveMemoryWarning
{
   [super didReceiveMemoryWarning];
   //TODO.
}

#pragma mark - refresh logic

//________________________________________________________________________________________
- (IBAction) refresh : (id) sender
{
#pragma unused(sender)

   if (internetReach && [internetReach currentReachabilityStatus] == CernAPP::NetworkStatus::notReachable) {
      CernAPP::ShowErrorAlert(@"Please, check network!", @"Close");
      return;
   }

   [self refresh];
}

//________________________________________________________________________________________
- (void) refresh
{
   self.navigationItem.rightBarButtonItem.enabled = NO;

   [self.collectionView reloadData];
   [noConnectionHUD hide : YES];

   CernAPP::ShowSpinner(self);

   [parser parseRecentWebcasts];
}

#pragma mark WebcastsParserDelegate methods

//________________________________________________________________________________________
- (void) webcastsParserDidFinishParsingRecentWebcasts : (WebcastsParser *) aParser
{
#pragma unused(aParser)

   webcasts = [parser.recentWebcasts copy];
   [self.collectionView reloadData];
   [self downloadVideoThumbnails];
}

//________________________________________________________________________________________
- (void) webcastsParserDidFinishParsingUpcomingWebcasts : (WebcastsParser *) parser
{
   //
   assert(0 && "noop");
}

//________________________________________________________________________________________
- (void) webcastsParser : (WebcastsParser *) parser didDownloadThumbnailForRecentWebcastIndex : (int) index
{
}

//________________________________________________________________________________________
- (void) webcastsParser : (WebcastsParser *) parser didDownloadThumbnailForUpcomingWebcastIndex : (int)index
{
}

//________________________________________________________________________________________
- (void) webcastsParser : (WebcastsParser *) parser didFailWithError : (NSError *) error
{
   CernAPP::HideSpinner(self);
   CernAPP::ShowErrorHUD(self, @"Network error");
   self.navigationItem.rightBarButtonItem.enabled = YES;
}

#pragma mark - Interface orientation

//________________________________________________________________________________________
- (BOOL) shouldAutorotate
{
   return NO;
}

#pragma mark - sliding view controller.

//________________________________________________________________________________________
- (IBAction) revealMenu : (id) sender
{
#pragma unused(sender)
   [self.slidingViewController anchorTopViewTo : ECRight];
}

#pragma mark - ImageDownloader.

//________________________________________________________________________________________
- (void) downloadVideoThumbnails
{
   assert(!imageDownloaders || !imageDownloaders.count &&
          "downloadVideoThumbnails, there are still active downloads");

   NSUInteger section = 0;
   imageDownloaders = [[NSMutableDictionary alloc] init];
   videoThumbnails = [[NSMutableDictionary alloc] init];
   for (NSDictionary *metaData in webcasts) {
      NSDictionary * const resources = (NSDictionary *)metaData[@"resources"];
   
      NSURL *url = nil;
      if ([resources objectForKey : @"jpgthumbnail"])
         url = [[resources objectForKey : @"jpgthumbnail"] objectAtIndex : 0];
      else
         url = [[resources objectForKey : @"pngthumbnail"] objectAtIndex : 0];
      
      if (url) {
         ImageDownloader * const downloader = [[ImageDownloader alloc] initWithURL : url];
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
   assert(indexPath.section < webcasts.count && "imageDidLoad:, section is out of bounds");
   
   ImageDownloader * const downloader = (ImageDownloader *)imageDownloaders[indexPath];
   assert(downloader != nil && "imageDidLoad:, no downloader found for the given index path");
   
   if (downloader.image) {
      assert(videoThumbnails[indexPath] == nil && "imageDidLoad:, image was loaded already");
      [videoThumbnails setObject : downloader.image forKey : indexPath];
      [self.collectionView reloadItemsAtIndexPaths : @[indexPath]];//may be, simply set an image for image view?
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
   assert(indexPath.section < webcasts.count && "imageDownloadFailed:, section is out of bounds");

   assert(imageDownloaders[indexPath] != nil &&
          "imageDownloadFailed:, no downloader for the given path");
   
   [imageDownloaders removeObjectForKey : indexPath];
   //But no need to update the collectionView.

   if (!imageDownloaders.count) {
      CernAPP::HideSpinner(self);
      self.navigationItem.rightBarButtonItem.enabled = YES;
   }
}

#pragma mark - UICollectionView data source

//________________________________________________________________________________________
- (NSInteger) numberOfSectionsInCollectionView : (UICollectionView *) collectionView
{
#pragma unused(collectionView)
   return webcasts.count;
}

//________________________________________________________________________________________
- (NSInteger) collectionView : (UICollectionView *) collectionView numberOfItemsInSection : (NSInteger) section
{
#pragma unused(collectionView)

   return 1;
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
   
   assert(indexPath.section >= 0 && indexPath.section < webcasts.count &&
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
   assert(indexPath.section < webcasts.count &&
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
      
      NSDictionary * const metaData = (NSDictionary *)webcasts[indexPath.section];
      
      
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

#pragma mark - UICollectionView delegate.

//________________________________________________________________________________________
- (void) collectionView : (UICollectionView *) collectionView didSelectItemAtIndexPath : (NSIndexPath *) indexPath
{
#pragma unused(collectionView)

   assert(indexPath != nil && "collectionView:didSelectItemAtIndexPath:, parameter 'indexPath' is nil");
   assert(indexPath.section >= 0 && indexPath.section < webcasts.count &&
          "collectionView:didSelectItemAtIndexPath:, section is out of bounds");

   NSDictionary * const webcast = (NSDictionary *)webcasts[indexPath.row];
   NSDictionary * const resources = (NSDictionary *)webcast[@"resources"];
   
   NSURL *url = (NSURL *)resources[@"mp40600"][0];
   if (!url)
      url = (NSURL *)resources[@"mp4mobile"][0];
   
   if (!url)
      return;
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
   [parser stopParser];
   [self cancelAllDownloaders];
}

@end
