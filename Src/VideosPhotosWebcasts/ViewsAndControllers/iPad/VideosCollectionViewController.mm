#import <MediaPlayer/MediaPlayer.h>

#import "VideosCollectionViewController.h"
#import "VideoThumbnailCell.h"
#import "CDSVideosParser.h"

@implementation VideosCollectionViewController

//________________________________________________________________________________________
- (id) initWithCoder : (NSCoder *) aDecoder
{
   if (self = [super initWithCoder : aDecoder]) {
      //
   }

   return self;
}

//________________________________________________________________________________________
- (void) didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

//________________________________________________________________________________________
- (NSInteger) numberOfSectionsInCollectionView : (UICollectionView *) collectionView
{
#pragma unused(collectionView)
   return 1;
}

//________________________________________________________________________________________
- (NSInteger) collectionView : (UICollectionView *) collectionView numberOfItemsInSection : (NSInteger) section
{
#pragma unused(collectionView)
   assert(section == 0 && "collectionView:numbefOfItemsInSection:, parameter 'section' is out of bounds");
   return videoMetadata.count;
}

//________________________________________________________________________________________
- (UICollectionViewCell *) collectionView : (UICollectionView *) collectionView cellForItemAtIndexPath : (NSIndexPath *) indexPath
{
   assert(collectionView != nil && "collectionView:cellForItemAtIndexPath:, parameter 'collectionView' is nil");
   assert(indexPath != nil && "collectionView:cellForItemAtIndexPath:, parameter 'indexPath' is nil");
   assert(indexPath.section == 0 && "collectionView:cellForItemAtIndexPath:, section index is out of bounds");
   assert(indexPath.row >= 0 && indexPath.row < videoMetadata.count &&
          "collectionView:cellForItemAtIndexPath:, row index is out of bounds");

   UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier : [VideoThumbnailCell cellReuseIdentifier] forIndexPath : indexPath];
   assert([cell isKindOfClass : [VideoThumbnailCell class]] &&
          "collectionView:cellForItemAtIndexPath:, reusable cell has a wrong type");
   
   VideoThumbnailCell * const videoCell = (VideoThumbnailCell *)cell;
   
   if (UIImage * const thumbnail = (UIImage *)videoThumbnails[indexPath])
      videoCell.imageView.image = thumbnail;
   else
      videoCell.imageView.image = nil;
   
   NSDictionary * const metaData = (NSDictionary *)videoMetadata[indexPath.row];
   NSString * const videoTitle = (NSString *)metaData[CernAPP::CDScodeTitle];
   if (videoTitle.length)
      videoCell.title = videoTitle;
   else
      videoCell.title = @"";

   return videoCell;
}

#pragma mark - UICollectionView data source.

//________________________________________________________________________________________
- (void) collectionView : (UICollectionView *) collectionView didSelectItemAtIndexPath : (NSIndexPath *) indexPath
{
#pragma unused(collectionView)

   assert(indexPath != nil && "collectionView:didSelectItemAtIndexPath:, parameter 'indexPath' is nil");
   assert(indexPath.section == 0 && "collectionView:didSelectItemAtIndexPath:, section index is out of bounds");
   assert(indexPath.row >= 0 && indexPath.row < videoMetadata.count &&
          "collectionView:didSelectItemAtIndexPath:, row index is out of bounds");

   NSDictionary * const video = (NSDictionary *)videoMetadata[indexPath.row];
   if (NSURL * const url = (NSURL *)video[CernAPP::CDSvideoURL]) {
      MPMoviePlayerViewController * const playerController = [[MPMoviePlayerViewController alloc] initWithContentURL : url];
      [self presentMoviePlayerViewControllerAnimated : playerController];
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

#pragma mark - ImageDownloader delegate and related methods.

//________________________________________________________________________________________
- (void) downloadVideoThumbnails
{
   NSUInteger row = 0;
   imageDownloaders = [[NSMutableDictionary alloc] init];
   videoThumbnails = [[NSMutableDictionary alloc] init];
   for (NSDictionary *metaData in videoMetadata) {
      ImageDownloader * const downloader = [[ImageDownloader alloc] initWithURL : (NSURL *)metaData[CernAPP::CDSvideoThubmnailURL]];
      NSIndexPath * const indexPath = [NSIndexPath indexPathForRow : row inSection : 0];
      downloader.indexPathInTableView = indexPath;
      downloader.delegate = self;
      [imageDownloaders setObject : downloader forKey : indexPath];
      [downloader startDownload];
      ++row;
   }
}

//________________________________________________________________________________________
- (void) imageDidLoad : (NSIndexPath *) indexPath
{
   //
   assert(indexPath != nil && "imageDidLoad, parameter 'indexPath' is nil");
   assert(indexPath.section == 0 && "imageDidLoad:, section index is out of bounds");
   assert(indexPath.row >= 0 && indexPath.row < videoMetadata.count && "imageDidLoad:, row index is out of bounds");
   
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
   assert(indexPath.section == 0 && "imageDownloadFailed:, section index is out of bounds");
   assert(indexPath.row >= 0 && indexPath.row < videoMetadata.count &&
          "imageDownloadFailed:, row index is out of bounds");

   assert(imageDownloaders[indexPath] != nil &&
          "imageDownloadFailed:, no downloader for the given path");
   
   [imageDownloaders removeObjectForKey : indexPath];
   //But no need to update the collectionView.

   if (!imageDownloaders.count) {
      CernAPP::HideSpinner(self);
      self.navigationItem.rightBarButtonItem.enabled = YES;
   }
}

#pragma mark - Interface orientation.

//________________________________________________________________________________________
- (BOOL) shouldAutorotate
{
   return YES;
}

@end
