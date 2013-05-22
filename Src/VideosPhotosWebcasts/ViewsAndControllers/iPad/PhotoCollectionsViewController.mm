#import <algorithm>

#import "PhotoCollectionsViewController.h"
#import "ECSlidingViewController.h"
#import "PhotoAlbumCoverView.h"
#import "AnimatedStackLayout.h"
#import "ImageStackCellView.h"
#import "ApplicationErrors.h"
#import "PhotoViewCell.h"
#import "Reachability.h"
#import "PhotoAlbum.h"

using CernAPP::ResourceTypeImageForPhotoBrowserIPAD;
using CernAPP::ResourceTypeThumbnail;
using CernAPP::NetworkStatus;

//TODO: This class or a some derived class should also replace a PhotoGridViewController (iPhone version, non-stacked mode).
namespace
{

//________________________________________________________________________________________
CGSize CellSizeFromImageSize(CGSize imageSize)
{
   CGSize cellSize = CGSizeMake(125.f, 125.f);
   if (imageSize.width > 0.f && imageSize.height > 0.f) {
      //
      const CGFloat maxFixed = 150.f;//150x150 - maximum possible size.
      //
      const CGFloat max = std::max(imageSize.width, imageSize.height);
      const CGFloat scale = maxFixed / max;
      cellSize.width = imageSize.width * scale;
      cellSize.height = imageSize.height * scale;
   }
   
   return cellSize;
}

}

@implementation PhotoCollectionsViewController {
   BOOL viewDidAppear;
   
   CernMediaMARCParser *parser;
   
   NSMutableDictionary *imageDownloaders;
   NSMutableDictionary *thumbnails;
   NSMutableArray *photoAlbumsStatic;//Loaded.
   NSMutableArray *photoAlbumsDynamic;//In process.
   
   NSIndexPath *selected;
   
   Reachability *internetReach;
   
   UICollectionView *albumCollectionView;
   BOOL isInTransition;
}

@synthesize noConnectionHUD, spinner;


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
      
      isInTransition = NO;
      albumCollectionView = nil;
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
   
   self.view.backgroundColor = [UIColor blackColor];
   
   albumCollectionView = [[UICollectionView alloc] initWithFrame:CGRect() collectionViewLayout : [[AnimatedStackLayout alloc] init]];
   albumCollectionView.hidden = YES;
   albumCollectionView.delegate = self;
   albumCollectionView.dataSource = self;
   //
   albumCollectionView.backgroundColor = [UIColor clearColor];
   //
   [self.view addSubview : albumCollectionView];
   [self.collectionView.superview bringSubviewToFront : self.collectionView];   

   [self.collectionView registerClass : [PhotoAlbumCoverView class]
           forCellWithReuseIdentifier : @"PhotoAlbumCoverView"];
   [albumCollectionView registerClass : [PhotoViewCell class]
           forCellWithReuseIdentifier : @"PhotoViewCell"];
   
   albumCollectionView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
                                          UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
                                          UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;

}

//________________________________________________________________________________________
- (void) viewDidAppear : (BOOL) animated
{
   if (!viewDidAppear) {
      viewDidAppear = YES;
      [self refresh];
   }
   
   albumCollectionView.frame = self.collectionView.frame;//TODO: test this!

   if (selected) {
      UICollectionViewCell * const cell = [self.collectionView cellForItemAtIndexPath : selected];
      [(AnimatedStackLayout *)albumCollectionView.collectionViewLayout setStackCenterNoUpdate : cell.center];
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
      //
      [self cancelAllImageDownloaders];//TODO: test??
      //
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
#pragma unused(collectionViewLayout)

   assert(indexPath != nil && "collectionView:layout:sizeForItemAtIndexPath:, parameter 'indexPath' is nil");

   if (collectionView == albumCollectionView) {
      assert(selected != nil &&
             "collectionView:layout:sizeForItemAtIndexPath:, no album was selected");
      PhotoAlbum * const album = (PhotoAlbum *)photoAlbumsStatic[selected.row];
      assert(indexPath.row < album.nImages &&
             "collectionView:layout:sizeForItemAtIndexPath:, row index is out of bounds");
      
      if (UIImage * const thumbnail = [album getThumbnailImageForIndex : indexPath.row]) {
         const CGSize cellSize = CellSizeFromImageSize(thumbnail.size);
         return cellSize;
      }
      
      return CGSizeMake(125.f, 125.f);
   }

   return CGSizeMake(200.f, 200.f);
}

//________________________________________________________________________________________
- (NSInteger) numberOfSectionsInCollectionView : (UICollectionView *) collectionView
{
   if (collectionView == albumCollectionView) {
      if (!selected)//assert?
         return 0;//TODO
    
      return 1;
   }

   if (!photoAlbumsStatic)
      return 0;

   return 1;
}

//________________________________________________________________________________________
- (NSInteger) collectionView : (UICollectionView *) collectionView numberOfItemsInSection : (NSInteger) section
{
   if (collectionView == albumCollectionView) {
      if (!selected)//assert?
         return 0;
      
      assert(selected.row < photoAlbumsStatic.count &&
             "numberOfSectionsInCollectionView:, selected.row is out of bounds");
      PhotoAlbum * const album = photoAlbumsStatic[selected.row];

      return album.nImages;
   }

   assert(section >= 0 && section < photoAlbumsStatic.count && "collectionView:numberOfItemsInSection:, index is out of bounds");

   return photoAlbumsStatic.count;
}


//________________________________________________________________________________________
- (UICollectionViewCell *) collectionView : (UICollectionView *) collectionView cellForItemAtIndexPath : (NSIndexPath *) indexPath
{
   assert(collectionView != nil && "collectionView:cellForItemAtIndexPath:, parameter 'collectionView' is nil");
   assert(indexPath != nil && "collectionView:cellForItemAtIndexPath:, parameter 'indexPath' is nil");

   if (collectionView == albumCollectionView) {
      UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier : @"PhotoViewCell" forIndexPath : indexPath];
      assert(!cell || [cell isKindOfClass : [PhotoViewCell class]] &&
             "collectionView:cellForItemAtIndexPath:, reusable cell has a wrong type");
      if (!cell)
         cell = [[PhotoViewCell alloc] initWithFrame : CGRect()];
      
      PhotoViewCell * const photoCell = (PhotoViewCell *)cell;
      if (selected) {
         assert(selected.row < photoAlbumsStatic.count &&
                "collectionView:cellForItemAtIndexPath:, selected.row is out of bounds");
         PhotoAlbum * const album = (PhotoAlbum *)photoAlbumsStatic[selected.row];
         if (UIImage * const image = [album getThumbnailImageForIndex : indexPath.row])
            photoCell.imageView.image = image;
      } else
         NSLog(@"nothing selected????");

      return photoCell;
   } else {
      UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier : @"PhotoAlbumCoverView" forIndexPath : indexPath];
      assert(!cell || [cell isKindOfClass : [PhotoAlbumCoverView class]] &&
             "collectionView:cellForItemAtIndexPath:, reusable cell has a wrong type");
      
      PhotoAlbumCoverView * const photoCell = (PhotoAlbumCoverView *)cell;
      
      assert(indexPath.section >= 0 && indexPath.section < photoAlbumsStatic.count &&
             "collectionView:cellForItemAtIndexPath:, section index is out of bounds");

      assert(indexPath.row >= 0 && indexPath.row < photoAlbumsStatic.count &&
             "collectionView:cellForItemAtIndexPath:, row index is out of bounds");
      PhotoAlbum * const album = (PhotoAlbum *)photoAlbumsStatic[indexPath.row];

      CGRect cellFrame = photoCell.frame;
      if (UIImage * const image = (UIImage *)thumbnails[indexPath]) {
         cellFrame.size = CellSizeFromImageSize(image.size);
         photoCell.imageView.image = image;
      } else {
         cellFrame.size = CGSizeMake(125.f, 125.f);
      }
         
      photoCell.frame = cellFrame;
      
      if (album.title.length)
         photoCell.title = album.title;

      return photoCell;
   }
}

#pragma mark - UICollectionView delegate + related methods.

//________________________________________________________________________________________
- (void) collectionView : (UICollectionView *) collectionView didSelectItemAtIndexPath : (NSIndexPath *) indexPath
{
   assert(indexPath != nil && "collectionView:didSelectItemAtIndexPath:, parameter 'indexPath' is nil");

   if (collectionView == albumCollectionView) {
      assert(selected != nil && "collectionView:didSelectItemAtIndexPath:, selected is nil");
      PhotoAlbum * const album = (PhotoAlbum *)photoAlbumsStatic[selected.row];
      assert(indexPath.row < album.nImages && "collectionView:didSelectItemAtIndexPath:, row is out of bounds");
      //Open MWPhotoBrowser.
      MWPhotoBrowser *browser = [[MWPhotoBrowser alloc] initWithDelegate : self];
      browser.displayActionButton = YES;
      [browser setInitialPageIndex : indexPath.row];

      UINavigationController * const navController = [[UINavigationController alloc] initWithRootViewController : browser];
      navController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
      [self presentViewController : navController animated : YES completion : nil];      
   } else {
      self.navigationItem.rightBarButtonItem.enabled = NO;
   
      //Here's the magic.
      UICollectionViewCell * const cell = [self.collectionView cellForItemAtIndexPath : indexPath];
      assert([albumCollectionView.collectionViewLayout isKindOfClass:[AnimatedStackLayout class]] &&
             "collectionView:didSelectItemAtIndexPath:, albumCollectionView has a wrong layout type");
      AnimatedStackLayout *layout = (AnimatedStackLayout *)albumCollectionView.collectionViewLayout;
      layout.stackCenter = cell.center;
      layout.stackFactor = 0.f;

      assert(indexPath.row < photoAlbumsStatic.count &&
             "collectionView:didSelectItemAtIndexPath:, row is out of bounds");

      selected = indexPath;
      [albumCollectionView reloadData];
      
      isInTransition = YES;

      self.collectionView.hidden = YES;
      albumCollectionView.hidden = NO;
      [albumCollectionView.superview bringSubviewToFront : albumCollectionView];
      
      [albumCollectionView performBatchUpdates : ^ {
         ((AnimatedStackLayout *)albumCollectionView.collectionViewLayout).stackFactor = 1.f;
      } completion : ^(BOOL finished) {
         if (finished) {
            [self swapNavigationBarButtons : NO];
            isInTransition = NO;
         }
      }];
   }
}

//________________________________________________________________________________________
- (void) switchToStackedMode : (id) sender
{
#pragma unused(sender)

   assert(self.collectionView.hidden == YES && "switchToStackedMode:, self.collectionView is already visible");
   assert(albumCollectionView.hidden == NO && "switchToStackedMode:, albumCollectionView is already hidden");

   self.navigationItem.rightBarButtonItem.enabled = NO;
   isInTransition = YES;

   self.collectionView.hidden = NO;
   [albumCollectionView performBatchUpdates : ^ {
      ((AnimatedStackLayout *)albumCollectionView.collectionViewLayout).stackFactor = 0.f;
   } completion : ^(BOOL finished) {
      [self.collectionView.superview bringSubviewToFront:self.collectionView];
      if (spinner.isAnimating)//Do not forget to show the spinner again, we are still loading.
         [spinner.superview bringSubviewToFront : spinner];
   
      albumCollectionView.hidden = YES;
      [self swapNavigationBarButtons : YES];
      isInTransition = NO;
      selected = nil;
   }];
}

//________________________________________________________________________________________
- (void) swapNavigationBarButtons : (BOOL) stackedMode
{
   if (stackedMode) {
      self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                                initWithBarButtonSystemItem : UIBarButtonSystemItemRefresh
                                                target : self action : @selector(reloadImages:)];
   } else {
      self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                                initWithTitle : @"Back to albums" style : UIBarButtonItemStyleDone
                                                target : self action : @selector(switchToStackedMode:)];
   }
}

#pragma mark - Interface orientation change.

//________________________________________________________________________________________
- (BOOL) shouldAutorotate
{
   return !isInTransition;
}

//________________________________________________________________________________________
- (void) willAnimateRotationToInterfaceOrientation : (UIInterfaceOrientation) toInterfaceOrientation duration : (NSTimeInterval)duration
{
   assert(isInTransition == NO &&
          "willAnimateRotationToInterfaceOrientation:duration:, called while stack animation is active");
   
   if (selected && !albumCollectionView.hidden) {
      //We (probably) have to find a new stack center.
      UICollectionViewCell * const cell = [self.collectionView cellForItemAtIndexPath : selected];
      [((AnimatedStackLayout *)albumCollectionView.collectionViewLayout) setStackCenterNoUpdate : cell.center];
   }
}

#pragma mark - ImageDownloaderDelegate and related methods.

//________________________________________________________________________________________
- (void) loadFirstThumbnails
{
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
      NSIndexPath * const key = [NSIndexPath indexPathForRow : indexPath.section inSection : 0];
      if (!thumbnails[key]) {
         [thumbnails setObject : downloader.image forKey : key];
         //It's a bit of a mess here - section goes to the row and becomes 0.
         [self.collectionView reloadItemsAtIndexPaths : @[[NSIndexPath indexPathForRow : indexPath.section inSection : 0]]];
         //Load other thumbnails (not visible in a stacked mode).
         [self loadThumbnailsForAlbum : indexPath.section];
      }
   } else if (indexPath.row + 1 < album.nImages) {
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
   
   NSIndexPath * const key = [NSIndexPath indexPathForRow : 0 inSection : indexPath.section];
   if (!thumbnails[key] && indexPath.row + 1 < album.nImages)//We're still trying to download an album's thumbnail.
      [self loadNextThumbnail : [NSIndexPath indexPathForRow : indexPath.row + 1 inSection : indexPath.section]];
   
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
   photoAlbumsStatic = [photoAlbumsDynamic mutableCopy];
   [thumbnails removeAllObjects];
   [self loadFirstThumbnails];
   [self.collectionView reloadData];
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

#pragma mark - MWPhotoBrowserDelegate.

//________________________________________________________________________________________
- (NSUInteger) numberOfPhotosInPhotoBrowser : (MWPhotoBrowser *) photoBrowser
{
#pragma unused(photoBrowser)

   assert(selected != nil && "numberOfPhotosInPhotoBrowser:, selected is nil");
   assert(selected.row < photoAlbumsStatic.count && "numberOfPhotosInPhotoBrowser:, row is out of bounds");

   PhotoAlbum * const album = (PhotoAlbum *)photoAlbumsStatic[selected.row];
   return album.nImages;
}

//________________________________________________________________________________________
- (MWPhoto *) photoBrowser : (MWPhotoBrowser *) photoBrowser photoAtIndex : (NSUInteger) index
{
#pragma unused(photoBrowser)
   assert(selected != nil && "photoBrowser:photoAtIndex:, selected is nil");
   assert(selected.row < photoAlbumsStatic.count &&
          "photoBrowser:photoAtIndex:, row is out of bounds");

   PhotoAlbum * const album = (PhotoAlbum *)photoAlbumsStatic[selected.row];
   assert(index < album.nImages && "photoBrowser:photoAtIndex:, index is out of bounds");

   NSURL * const url = [album getImageURLWithIndex : index forType : ResourceTypeImageForPhotoBrowserIPAD];
   return [MWPhoto photoWithURL : url];
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
