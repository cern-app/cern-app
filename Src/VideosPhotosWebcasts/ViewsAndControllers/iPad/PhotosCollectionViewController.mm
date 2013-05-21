#import <algorithm>

#import "PhotosCollectionViewController.h"
#import "ECSlidingViewController.h"
#import "PhotoAlbumCoverView.h"
#import "ImageStackCellView.h"
#import "ApplicationErrors.h"
#import "PhotoViewCell.h"
#import "Reachability.h"
#import "PhotoAlbum.h"

using CernAPP::ResourceTypeThumbnail;
using CernAPP::NetworkStatus;

@implementation PhotosCollectionViewController {
   BOOL viewDidAppear;
   
   CernMediaMARCParser *parser;
   
   NSMutableDictionary *imageDownloaders;
   NSMutableDictionary *thumbnails;
   NSMutableArray *photoAlbumsStatic;//Loaded.
   NSMutableArray *photoAlbumsDynamic;//In process.
   
   Reachability *internetReach;
}

@synthesize noConnectionHUD, spinner, stackedMode;


#pragma mark - Network reachability.

//________________________________________________________________________________________
- (void) reachabilityStatusChanged : (Reachability *) current
{
#pragma unused(current)
   
   if (internetReach && [internetReach currentReachabilityStatus] == NetworkStatus::notReachable) {
      //Depending on what we do now and what we have now ...
      if (!parser.isFinishedParsing)
         [parser stop];
      
      [self cancelAllImageDownloaders];
      self.navigationItem.rightBarButtonItem.enabled = YES;
   }
}

//________________________________________________________________________________________
- (bool) hasConnection
{
   return internetReach && [internetReach currentReachabilityStatus] != NetworkStatus::notReachable;
}

#pragma mark - Lifecycle

//________________________________________________________________________________________
- (id) initWithCoder : (NSCoder *) aDecoder
{
   if (self = [super initWithCoder : aDecoder]) {
      parser = [[CernMediaMARCParser alloc] init];
      parser.delegate = self;
      parser.resourceTypes = @[@"jpgA4", @"jpgA5", @"jpgIcon"];
      //
      imageDownloaders = [[NSMutableDictionary alloc] init];
      thumbnails = [[NSMutableDictionary alloc] init];
      photoAlbumsStatic = nil;
      photoAlbumsDynamic = [[NSMutableArray alloc] init];
      
      [[NSNotificationCenter defaultCenter] addObserver : self selector : @selector(reachabilityStatusChanged:) name : CernAPP::reachabilityChangedNotification object : nil];
      internetReach = [Reachability reachabilityForInternetConnection];
      [internetReach startNotifier];
   }

   return self;
}

//________________________________________________________________________________________
- (void) dealloc
{
   [internetReach stopNotifier];
   [[NSNotificationCenter defaultCenter] removeObserver : self];
}

#pragma mark - viewDid/Done/Does/Will etc.

//________________________________________________________________________________________
- (void) viewDidLoad
{
   [super viewDidLoad];
   //
   CernAPP::AddSpinner(self);
   CernAPP::HideSpinner(self);
   
   [self.collectionView registerClass : [PhotoAlbumCoverView class]
           forCellWithReuseIdentifier : @"PhotoAlbumCoverView"];
}

//________________________________________________________________________________________
- (void) viewDidAppear : (BOOL) animated
{
   if (!viewDidAppear) {
      viewDidAppear = YES;
      
      /*
      assert([self.collectionView.collectionViewLayout isKindOfClass : [PhotosCollectionViewLayout class]] &&
                "viewDidAppear:, collection view has a wrong layout type");
      PhotosCollectionViewLayout * const layout = (PhotosCollectionViewLayout *)self.collectionView.collectionViewLayout;
      if (self.collectionView.frame.size.width > self.collectionView.frame.size.height)
         layout.numberOfColumns = 4;
      else
         layout.numberOfColumns = 3;
      */
      
      [self refresh];
   }
}

#pragma mark - Misc. methods.

//________________________________________________________________________________________
- (void) setURL : (NSURL *) url
{
   assert(url != nil && "setURL:, parameter 'url' is nil");
   assert(parser != nil && "setURL:, parser is uninitialized");
   
   parser.url = url;
}

#pragma mark - General controller's logic.

//________________________________________________________________________________________
- (void) refresh
{
   if (parser.isFinishedParsing) {
      [photoAlbumsDynamic removeAllObjects];
      [noConnectionHUD hide : YES];
      
      self.navigationItem.rightBarButtonItem.enabled = NO;
      
      CernAPP::ShowSpinner(self);
      [parser parse];
   }
}

#pragma mark - UIViewCollectionDataSource

//________________________________________________________________________________________
- (CGSize) collectionView : (UICollectionView *) collectionView layout : (UICollectionViewLayout*) collectionViewLayout
           sizeForItemAtIndexPath : (NSIndexPath *) indexPath
{
#pragma unused(collectionView, collectionViewLayout, indexPath)
   return CGSizeMake(200.f, 200.f);
}

//________________________________________________________________________________________
- (NSInteger) numberOfSectionsInCollectionView : (UICollectionView *) collectionView
{
#pragma unused(collectionView)
   if (!photoAlbumsStatic)
      return 0;

   return 1;
}

//________________________________________________________________________________________
- (NSInteger) collectionView : (UICollectionView *) collectionView numberOfItemsInSection : (NSInteger) section
{
#pragma unused(collectionView)
   assert(section >= 0 && section < photoAlbumsStatic.count && "collectionView:numberOfItemsInSection:, index is out of bounds");

   assert(stackedMode == YES && "non-stacked, not-implemented yet");

   return photoAlbumsStatic.count;
}


//________________________________________________________________________________________
- (UICollectionViewCell *) collectionView : (UICollectionView *) collectionView cellForItemAtIndexPath : (NSIndexPath *) indexPath
{
   assert(collectionView != nil && "collectionView:cellForItemAtIndexPath:, parameter 'collectionView' is nil");
   assert(indexPath != nil && "collectionView:cellForItemAtIndexPath:, parameter 'indexPath' is nil");

   assert(stackedMode == YES && "non-stacked, not-implemented");

   UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier : @"PhotoAlbumCoverView" forIndexPath : indexPath];
   assert(!cell || [cell isKindOfClass : [PhotoAlbumCoverView class]] &&
          "collectionView:cellForItemAtIndexPath:, reusable cell has a wrong type");
   
   PhotoAlbumCoverView * const photoCell = (PhotoAlbumCoverView *)cell;
   
   assert(indexPath.section >= 0 && indexPath.section < photoAlbumsStatic.count &&
          "collectionView:cellForItemAtIndexPath:, section index is out of bounds");

   assert(indexPath.row >= 0 && indexPath.row < photoAlbumsStatic.count &&
          "collectionView:cellForItemAtIndexPath:, row index is out of bounds");
   PhotoAlbum * const album = (PhotoAlbum *)photoAlbumsStatic[indexPath.row];

   if (stackedMode) {
      if (UIImage * const image = (UIImage *)thumbnails[indexPath])
         photoCell.imageView.image = image;
   } else
      photoCell.imageView.image = [album getThumbnailImageForIndex : indexPath.row];
   
   if (album.title.length)
      photoCell.title = album.title;

   photoCell.alpha = 0.2f;

   return photoCell;
}

#pragma mark - ImageDownloaderDelegate and related methods.

//________________________________________________________________________________________
- (void) loadFirstThumbnails
{
   assert(stackedMode == YES &&
          "loadFirstThumbnails, can be called only in a stacked mode");

   if (imageDownloaders.count)
      return;
   
   if (!photoAlbumsStatic.count)
      return;

   for (NSUInteger i = 0, e = photoAlbumsStatic.count; i < e; ++i)
      [self loadNextThumbnail : [NSIndexPath indexPathForRow : 0 inSection : i]];
}

//________________________________________________________________________________________
- (void) loadNextThumbnail : (NSIndexPath *) indexPath
{
   assert(stackedMode == YES && "loadNextThumbnail:, can be called only in a stacked mode");

   assert(indexPath != nil && "loadNextThumbnail:, parameter 'indexPath' is nil");
   assert(indexPath.section < photoAlbumsStatic.count && "loadNextThumbnail:, section index is out of bounds");
   PhotoAlbum * const album = (PhotoAlbum *)photoAlbumsStatic[indexPath.section];
   assert(indexPath.row < album.nImages && "loadNextThumbnail:, row index is out of bounds");

   ImageDownloader * const downloader = [[ImageDownloader alloc] initWithURL :
                                         [album getImageURLWithIndex : indexPath.row + 1 forType : ResourceTypeThumbnail]];
   downloader.delegate = self;
   downloader.indexPathInTableView = indexPath;
   [imageDownloaders setObject : downloader forKey : indexPath];
   [downloader startDownload];
}

//________________________________________________________________________________________
- (void) loadThumbnailsForAlbum : (NSUInteger) index
{
   assert(index < photoAlbumsStatic.count && "loadThumbnailsForAlbum:, parameter 'index' is out of bounds");
   
   PhotoAlbum * const album = (PhotoAlbum *)photoAlbumsStatic[index];
   for (NSUInteger i = 0, e = album.nImages; i < e; ++i) {
      NSIndexPath * const key = [NSIndexPath indexPathForRow : i inSection : index];
      if ([album getThumbnailImageForIndex : i] || imageDownloaders[key])
         continue;
      ImageDownloader * const downloader = [[ImageDownloader alloc] initWithURL :
                                            [album getImageURLWithIndex : i forType : ResourceTypeThumbnail]];
      downloader.indexPathInTableView = key;
      downloader.delegate = self;
      [imageDownloaders setObject : downloader forKey : key];
      [downloader startDownload];
   }
}

//________________________________________________________________________________________
- (void) imageDidLoad : (NSIndexPath *) indexPath
{
   assert(indexPath != nil && "imageDidLoad:, parameter 'indexPath' is nil");
   assert(indexPath.section < photoAlbumsStatic.count &&
          "imageDidLoad:, section index is out of bounds");
   
   PhotoAlbum * const album = (PhotoAlbum *)photoAlbumsStatic[indexPath.section];
   assert(indexPath.row < album.nImages && "imageDidLoad:, row index is out of bounds");
   
   ImageDownloader * const downloader = (ImageDownloader *)imageDownloaders[indexPath];
   assert(downloader != nil && "imageDidLoad:, no downloader found for indexPath");
   [imageDownloaders removeObjectForKey : indexPath];
   
   if (downloader.image) {
      [album setThumbnailImage : downloader.image withIndex : indexPath.row];
      //Here we have to do some magic:
      if (stackedMode) {
         NSIndexPath * const key = [NSIndexPath indexPathForRow : indexPath.section inSection : 0];
         if (!thumbnails[key]) {
            [thumbnails setObject : downloader.image forKey : key];
            //It's a bit of a mess here - section goes to the row and becomes 0.
            [self.collectionView reloadItemsAtIndexPaths : @[[NSIndexPath indexPathForRow : indexPath.section inSection : 0]]];
            //Load other thumbnails (not visible in a stacked mode).
            [self loadThumbnailsForAlbum : indexPath.section];
         }
      } else {
         //TODO: non-stacked mode is not implemented.
         assert(0 && "imageDidLoad:, not implemented");
      }
   } else if (stackedMode && indexPath.row + 1 < album.nImages) {
      //Ooops, but we can still try to download the next thumbnail?
      [self loadNextThumbnail : [NSIndexPath indexPathForRow : indexPath.row + 1 inSection : indexPath.section]];
   }
   
   if (!imageDownloaders.count) {
      self.navigationItem.rightBarButtonItem.enabled = YES;
      CernAPP::HideSpinner(self);
   }
}

//________________________________________________________________________________________
- (void) imageDownloadFailed : (NSIndexPath *) indexPath
{
   assert(indexPath != nil && "imageDownloadFailed:, parameter 'indexPath' is nil");
   assert(indexPath.section < photoAlbumsStatic.count &&
          "imageDownloadFailed:, section index is out of bounds");

   PhotoAlbum * const album = (PhotoAlbum *)photoAlbumsStatic[indexPath.section];
   assert(indexPath.row < album.nImages &&
          "imageDownloadFailed:, row index is out of bounds");

   assert(imageDownloaders[indexPath] != nil && "imageDownloadFailed:, no downloader found for indexPath");
   [imageDownloaders removeObjectForKey : indexPath];
   
   if (stackedMode) {
      NSIndexPath * const key = [NSIndexPath indexPathForRow : 0 inSection : indexPath.section];
      if (!thumbnails[key] && indexPath.row + 1 < album.nImages)//We're still trying to download an album's thumbnail.
         [self loadNextThumbnail : [NSIndexPath indexPathForRow : indexPath.row + 1 inSection : indexPath.section]];
   } else {
      //TODO: non-stacked mode is not implemented.
      assert(0 && "imageDownloadFailed:, not implemented");
   }
   
   if (!imageDownloaders.count) {
      self.navigationItem.rightBarButtonItem.enabled = YES;   
      CernAPP::HideSpinner(self);
   }
}

#pragma mark - CERNMediaMARCParser delegate.

//________________________________________________________________________________________
- (void) parser : (CernMediaMARCParser *) aParser didParseRecord : (NSDictionary *) record
{
   assert(parser.isFinishedParsing == NO && "parser:didParseRecord:, not parsing at the moment");

   //Eamon:
   // "we will assume that each array in the dictionary has the same number of photo urls".
   //Me:
   // No, this assumption does not work :( some images can be omitted - for example, 'jpgIcon'.

   assert(aParser != nil && "parser:didParseRecord:, parameter 'aParser' is null");
   assert(record != nil && "parser:didParseRecord:, parameter 'record' is null");

   //Now, we do some magic to fix bad assumptions.

   NSDictionary * const resources = (NSDictionary *)record[@"resources"];
   assert(resources != nil && "parser:didParseRecord:, no object for the key 'resources' was found");
   
   const NSUInteger nPhotos = ((NSArray *)resources[aParser.resourceTypes[0]]).count;
   for (NSUInteger i = 1, e = aParser.resourceTypes.count; i < e; ++i) {
      NSArray * const typedData = (NSArray *)[resources objectForKey : [aParser.resourceTypes objectAtIndex : i]];
      if (typedData.count != nPhotos) {
         //I simply ignore this record - have no idea what to do with such a data.
         return;
      }
   }

   PhotoAlbum * const newAlbum = [[PhotoAlbum alloc] init];

   NSArray * const a4Data = (NSArray *)resources[@"jpgA4"];
   NSArray * const a5Data = (NSArray *)resources[@"jpgA5"];
   NSArray * const iconData = (NSArray *)resources[@"jpgIcon"];

   for (NSUInteger i = 0; i < nPhotos; i++) {
      NSDictionary * const newImageData = @{@"jpgA4" : a4Data[i], @"jpgA5" : a5Data[i], @"jpgIcon" : iconData[i]};
      [newAlbum addImageData : newImageData];
   }
   
   newAlbum.title = record[@"title"];
   [photoAlbumsDynamic addObject : newAlbum];
}

//________________________________________________________________________________________
- (void) parserDidFinish : (CernMediaMARCParser *) aParser
{
#pragma unused(aParser)

   //We start downloading images here.
   if (stackedMode) {
      photoAlbumsStatic = [photoAlbumsDynamic mutableCopy];
      [self loadFirstThumbnails];
      [self.collectionView reloadData];
   } else {
      assert(0 && "parserDidFinish:, not implemented");
   }
}

//________________________________________________________________________________________
- (void) parser : (CernMediaMARCParser *) aParser didFailWithError : (NSError *) error
{
#pragma unused(aParser)
   CernAPP::HideSpinner(self);
   
   self.navigationItem.rightBarButtonItem.enabled = YES;
   
   if (!photoAlbumsStatic.count)
      CernAPP::ShowErrorHUD(self, @"Network error");
   else
      CernAPP::ShowErrorAlert(@"Please, check network!", @"Close");
}

#pragma mark - ConnectionController delegate and related methods.

//________________________________________________________________________________________
- (void) cancelAllImageDownloaders
{
   for (ImageDownloader *downloader in imageDownloaders)
      [downloader cancelDownload];
   
   [imageDownloaders removeAllObjects];
}

//________________________________________________________________________________________
- (void) cancelAnyConnections
{
   [parser stop];
   [self cancelAllImageDownloaders];
}

#pragma mark - UI.

//________________________________________________________________________________________
- (IBAction) reloadImages : (id) sender
{
#pragma unused(sender)

   if (parser.isFinishedParsing) {
      if (![self hasConnection])
         CernAPP::ShowErrorAlert(@"Please, check network!", @"Close");
      else
         [self refresh];
   }
}

#pragma mark - ECSlidingViewController.

//________________________________________________________________________________________
- (IBAction) revealMenu : (id) sender
{
#pragma unused(sender)
   //
   [self.slidingViewController anchorTopViewTo : ECRight];
}

@end