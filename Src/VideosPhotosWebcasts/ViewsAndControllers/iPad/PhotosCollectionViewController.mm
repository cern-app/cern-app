#import "PhotosCollectionViewController.h"
#import "ECSlidingViewController.h"
#import "ApplicationErrors.h"
#import "PhotoViewCell.h"
#import "PhotoAlbum.h"

using CernAPP::ResourceTypeThumbnail;

@implementation PhotosCollectionViewController {
   BOOL viewDidAppear;
   
   NSMutableDictionary *imageDownloaders;
   NSMutableArray *photoAlbums;
}

@synthesize noConnectionHUD, spinner, stackedMode;

#pragma mark - Lifecycle

//________________________________________________________________________________________
- (id) initWithCoder : (NSCoder *) aDecoder
{
   if (self = [super initWithCoder : aDecoder]) {
      //
      photoAlbums = [[NSMutableArray alloc] init];
   }

   return self;
}

#pragma mark - viewDid/Done/Does/Will etc.

//________________________________________________________________________________________
- (void) viewDidLoad
{
   [super viewDidLoad];
   //
   CernAPP::AddSpinner(self);
   CernAPP::HideSpinner(self);
   
   [self.collectionView registerClass : [PhotoViewCell class]
           forCellWithReuseIdentifier : @"PhotoViewCell"];
}

//________________________________________________________________________________________
- (void) viewDidAppear : (BOOL) animated
{
   if (!viewDidAppear) {
      viewDidAppear = YES;
      [self refresh];
   }
}

#pragma mark - General controller's logic.

//________________________________________________________________________________________
- (void) refresh
{
   /*
   if (!photoDownloader.isDownloading) {
      [noConnectionHUD hide : YES];

      //TODO: check the network before doing anything at all?
      CernAPP::ShowSpinner(self);
      self.navigationItem.rightBarButtonItem.enabled = NO;
      [photoDownloader parse];
   }
   */
}

#pragma mark - UIViewCollectionDataSource

//________________________________________________________________________________________
- (NSInteger) numberOfSectionsInCollectionView : (UICollectionView *) collectionView
{
#pragma unused(collectionView)
   return photoAlbums.count;
}

//________________________________________________________________________________________
- (NSInteger) collectionView : (UICollectionView *) collectionView numberOfItemsInSection : (NSInteger) section
{
#pragma unused(collectionView)
   assert(section >= 0 && section < photoAlbums.count && "collectionView:numberOfItemsInSection:, index is out of bounds");

   PhotoAlbum * const album = (PhotoAlbum *)photoAlbums[section];
   return album.nImages;
}

/*
//________________________________________________________________________________________
- (UICollectionViewCell *) collectionView : (UICollectionView *) collectionView cellForItemAtIndexPath : (NSIndexPath *) indexPath
{
   assert(collectionView != nil && "collectionView:cellForItemAtIndexPath:, parameter 'collectionView' is nil");
   assert(indexPath != nil && "collectionView:cellForItemAtIndexPath:, parameter 'indexPath' is nil");

   UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier : @"PhotoViewCell" forIndexPath : indexPath];
   assert(!cell || [cell isKindOfClass : [PhotoViewCell class]] &&
          "collectionView:cellForItemAtIndexPath:, reusable cell has a wrong type");
   
   PhotoViewCell * const photoCell = (PhotoViewCell *)cell;
   
   assert(indexPath.section >= 0 && indexPath.section < photoSets.count &&
          "collectionView:cellForItemAtIndexPath:, section index is out of bounds");

   PhotoSet * const photoSet = (PhotoSet *)photoSets[indexPath.section];
   
   assert(indexPath.row >= 0 && indexPath.row < photoSet.nImages && "collectionView:cellForItemAtIndexPath:, row index is out of bounds");
   
   photoCell.imageView.image = [photoSet getThumbnailImageForIndex : indexPath.row];
   
   return photoCell;
}
*/

/*
//________________________________________________________________________________________
- (UICollectionReusableView *) collectionView : (UICollectionView *) collectionView
                               viewForSupplementaryElementOfKind : (NSString *) kind atIndexPath : (NSIndexPath *) indexPath
{
   assert(collectionView != nil &&
          "collectionView:viewForSupplementaryElementOfKinf:atIndexPath:, parameter 'collectionView' is nil");
   assert(indexPath != nil &&
          "collectionView:viewForSupplementaryElementOfKinf:atIndexPath:, parameter 'indexPath' is nil");
   assert(indexPath.section < photoSets.count &&
         "collectionView:viewForSupplementaryElementOfKinf:atIndexPath:, indexPath.section is out of bounds");

   UICollectionReusableView *view = nil;

   if ([kind isEqualToString:UICollectionElementKindSectionHeader]) {
      //
      view = [collectionView dequeueReusableSupplementaryViewOfKind : kind
                             withReuseIdentifier : @"SetInfoView" forIndexPath : indexPath];

      assert(!view || [view isKindOfClass : [PhotoSetInfoView class]] &&
             "collectionView:viewForSupplementaryElementOfKinf:atIndexPath:, reusable view has a wrong type");

      PhotoSetInfoView * infoView = (PhotoSetInfoView *)view;
      PhotoSet * const photoSet = (PhotoSet *)photoSets[indexPath.section];
      infoView.descriptionLabel.text = photoSet.title;
      
      UIFont * const font = [UIFont fontWithName : CernAPP::childMenuFontName size : 12.f];
      assert(font != nil && "collectionView:viewForSupplementaryElementOfKinf:atIndexPath:, font not found");
      infoView.descriptionLabel.font = font;
   } else {
      //Footer.
      view = [collectionView dequeueReusableSupplementaryViewOfKind : kind
                             withReuseIdentifier : @"SetFooter" forIndexPath : indexPath];

      assert(!view || [view isKindOfClass : [PhotoSetInfoView class]] &&
             "collectionView:viewForSupplementaryElementOfKinf:atIndexPath:, reusable view has a wrong type");
   }
   
   return view;
}
*/

#pragma mark - PhotoDownloaderDelegate methods

/*
//________________________________________________________________________________________
- (void) photoDownloaderDidFinish : (PhotoDownloader *) aPhotoDownloader
{
   photoSets = [aPhotoDownloader.photoSets copy];//This is non-compacted sets without images.
   [self.collectionView reloadData];
}

//________________________________________________________________________________________
- (void) photoDownloader : (PhotoDownloader *) photoDownloader didDownloadThumbnail : (NSUInteger) imageIndex forSet : (NSUInteger) setIndex
{
   NSIndexPath * const indexPath = [NSIndexPath indexPathForRow : imageIndex inSection : setIndex];
   [self.collectionView reloadItemsAtIndexPaths : @[indexPath]];
}


//________________________________________________________________________________________
- (void) photoDownloader : (PhotoDownloader *) photoDownloader didFailWithError : (NSError *) error
{
#pragma unused(error)
   
   self.navigationItem.rightBarButtonItem.enabled = YES;
   
   CernAPP::HideSpinner(self);
   CernAPP::ShowErrorHUD(self, @"Netword error");
}

//________________________________________________________________________________________
- (void) photoDownloaderDidFinishLoadingThumbnails : (PhotoDownloader *) aPhotoDownloader
{
#pragma unused(aPhotoDownloader)
   CernAPP::HideSpinner(self);
   [photoDownloader compactData];
   photoSets = [photoDownloader.photoSets copy];
   self.navigationItem.rightBarButtonItem.enabled = YES;
   [self.collectionView reloadData];
}
*/

#pragma mark - ImageDownloaderDelegate and related methods.

//________________________________________________________________________________________
- (void) loadFirstThumbnails
{
   assert(stackedMode == YES &&
          "loadFirstThumbnails, can be called only in a stacked mode");

   if (imageDownloaders.count)
      return;
   
   if (!photoAlbums.count)
      return;

   for (NSUInteger i = 0, e = photoAlbums.count; i < e; ++i)
      [self loadNextThumbnail : [NSIndexPath indexPathForRow : 0 inSection : i]];
}

//________________________________________________________________________________________
- (void) loadNextThumbnail : (NSIndexPath *) indexPath
{
   assert(stackedMode == YES && "loadNextThumbnail:, can be called only in a stacked mode");

   assert(indexPath != nil && "loadNextThumbnail:, parameter 'indexPath' is nil");
   assert(indexPath.section < photoAlbums.count && "loadNextThumbnail:, section index is out of bounds");
   PhotoAlbum * const album = (PhotoAlbum *)photoAlbums[indexPath.section];
   assert(indexPath.row + 1 < album.nImages && "loadNextThumbnail:, row index is out of bounds");
   
   ImageDownloader * const downloader = [[ImageDownloader alloc] initWithURL :
                                         [album getImageURLWithIndex : indexPath.row + 1 forType : ResourceTypeThumbnail]];
   NSIndexPath * const key = [NSIndexPath indexPathForRow : indexPath.row + 1 inSection : indexPath.section];
   downloader.indexPathInTableView = key;
   [imageDownloaders setObject : downloader forKey : key];
   [downloader startDownload];
}

//________________________________________________________________________________________
- (void) loadThumbnails
{
   //Load everything here.
}


//________________________________________________________________________________________
- (void) imageDidLoad : (NSIndexPath *) indexPath
{
   assert(indexPath != nil && "imageDidLoad:, parameter 'indexPath' is nil");
   assert(indexPath.section < photoAlbums.count &&
          "imageDidLoad:, section index is out of bounds");
   
   PhotoAlbum * const album = (PhotoAlbum *)photoAlbums[indexPath.section];
   assert(indexPath.row < album.nImages && "imageDidLoad:, row index is out of bounds");
   
   ImageDownloader * const downloader = (ImageDownloader *)imageDownloaders[indexPath];
   assert(downloader != nil && "imageDidLoad:, no downloader found for indexPath");
   [imageDownloaders removeObjectForKey : indexPath];

   if (downloader.image) {
      [album setThumbnailImage : downloader.image withIndex : indexPath.row];
      //Here we have to do some magic:
      if (stackedMode) {
         //Check, if the cell is not on the top ... reload to cells:
         //change the z order for the first one and indexPath.row.
         //invalidate layout.
         //TODO: TEST that this works if some downloads failed.
      } else {
         //Reload cell at ....
         [self.collectionView reloadItemsAtIndexPaths : @[indexPath]];
      }
   } else if (stackedMode && indexPath.row + 1 < album.nImages) {
      //Ooops, but we can still try to download the next thumbnail?
      [self loadNextThumbnail : [NSIndexPath indexPathForRow : indexPath.row + 1 inSection : indexPath.section]];
   }
}

//________________________________________________________________________________________
- (void) imageDownloadFailed : (NSIndexPath *) indexPath
{
   assert(indexPath != nil && "imageDownloadFailed:, parameter 'indexPath' is nil");
   assert(indexPath.section < photoAlbums.count &&
          "imageDownloadFailed:, section index is out of bounds");

   PhotoAlbum * const album = (PhotoAlbum *)photoAlbums[indexPath.section];
   assert(indexPath.row < album.nImages &&
          "imageDownloadFailed:, row index is out of bounds");

   assert(imageDownloaders[indexPath] != nil && "imageDownloadFailed:, no downloader found for indexPath");
   [imageDownloaders removeObjectForKey : indexPath];
   
   if (stackedMode) {
      //We still 
      if (indexPath.row + 1 < album.nImages) //Try again!
         [self loadNextThumbnail:[NSIndexPath indexPathForRow:indexPath.row + 1 inSection:indexPath.section]];
   }
}

#pragma mark - UI.

//________________________________________________________________________________________
- (IBAction) reloadImages : (id) sender
{
#pragma unused(sender)
/*
   if (!photoDownloader.isDownloading) {
      if (!photoDownloader.hasConnection)
         CernAPP::ShowErrorAlert(@"Please, check network!", @"Close");
      else
         [self refresh];
   }
   */
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