#import "PhotosCollectionViewController.h"
#import "ECSlidingViewController.h"
#import "ApplicationErrors.h"

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

#pragma mark - PhotoDownloaderDelegate methods

//________________________________________________________________________________________
- (void) photoDownloaderDidFinish : (PhotoDownloader *) aPhotoDownloader
{
   photoSets = [aPhotoDownloader.photoSets copy];//This is non-compacted sets without images.
 //  [self.collectionView reloadData];
}

//________________________________________________________________________________________
- (void) photoDownloader : (PhotoDownloader *) photoDownloader didDownloadThumbnail : (NSUInteger) imageIndex forSet : (NSUInteger) setIndex
{
//   NSIndexPath * const indexPath = [NSIndexPath indexPathForRow : imageIndex inSection : setIndex];

//   [self.collectionView reloadItemsAtIndexPaths : @[indexPath]];
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
//   [self.collectionView reloadData];
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