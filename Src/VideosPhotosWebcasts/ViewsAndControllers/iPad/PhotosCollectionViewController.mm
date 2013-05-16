#import "PhotosCollectionViewController.h"
#import "ECSlidingViewController.h"
#import "ApplicationErrors.h"
#import "PhotoViewCell.h"

@implementation PhotosCollectionViewController {
   BOOL viewDidAppear;
   
   NSArray *photoSets;
}

@synthesize noConnectionHUD, spinner, photoDownloader;

#pragma mark - Lifecycle

//________________________________________________________________________________________
- (id) initWithCoder : (NSCoder *) aDecoder
{
   if (self = [super initWithCoder:aDecoder]) {
      photoDownloader = [[PhotoDownloader alloc] init];
      photoDownloader.delegate = self;
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
   if (!photoDownloader.isDownloading) {
      [noConnectionHUD hide : YES];

      //TODO: check the network before doing anything at all?
      CernAPP::ShowSpinner(self);
      self.navigationItem.rightBarButtonItem.enabled = NO;
      [photoDownloader parse];
   }
}

#pragma mark - UIViewCollectionDataSource

//________________________________________________________________________________________
- (NSInteger) numberOfSectionsInCollectionView : (UICollectionView *) collectionView
{
#pragma unused(collectionView)
   return photoSets.count;
}

//________________________________________________________________________________________
- (NSInteger) collectionView : (UICollectionView *) collectionView numberOfItemsInSection : (NSInteger) section
{
#pragma unused(collectionView)
   assert(section >= 0 && section < photoSets.count && "collectionView:numberOfItemsInSection:, index is out of bounds");
   PhotoSet * const photoSet = (PhotoSet *)photoSets[section];

   return photoSet.nImages;
}

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


#pragma mark - UI.

//________________________________________________________________________________________
- (IBAction) reloadImages : (id) sender
{
#pragma unused(sender)
   if (!photoDownloader.isDownloading) {
      if (!photoDownloader.hasConnection)
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