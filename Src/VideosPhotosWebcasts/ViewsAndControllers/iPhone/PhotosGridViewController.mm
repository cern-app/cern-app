//
//  PhotosViewController.m
//  CERN App
//
//  Created by Eamon Ford on 6/27/12.
//  Copyright (c) 2012 CERN. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

#import "PhotosGridViewController.h"
#import "ECSlidingViewController.h"
#import "CernMediaMARCParser.h"
#import "PhotoGridViewCell.h"
#import "ApplicationErrors.h"
#import "PhotoSetInfoView.h"
#import "MBProgressHUD.h"
#import "GUIHelpers.h"

@implementation PhotosGridViewController {
   UIActivityIndicatorView *spinner;

   MBProgressHUD *noConnectionHUD;
   
   NSUInteger selectedSection;
   NSArray *photoSets;
   BOOL loaded;
}

@synthesize photoDownloader;

//________________________________________________________________________________________
- (id) initWithCoder : (NSCoder *) aDecoder
{
   if (self = [super initWithCoder:aDecoder]) {
      self.photoDownloader = [[PhotoDownloader alloc] init];
      self.photoDownloader.delegate = self;
   }

   return self;
}

//________________________________________________________________________________________
- (void) viewDidLoad
{
   [super viewDidLoad];
   //
   using CernAPP::spinnerSize;

   const CGPoint spinnerOrigin = CGPointMake(self.view.frame.size.width / 2 - spinnerSize / 2, self.view.frame.size.height / 2 - spinnerSize / 2);
   spinner = [[UIActivityIndicatorView alloc] initWithFrame : CGRectMake(spinnerOrigin.x, spinnerOrigin.y, spinnerSize, spinnerSize)];
   spinner.color = [UIColor grayColor];
   [self.view addSubview : spinner];
   [self hideSpinner];
}

//________________________________________________________________________________________
- (void) viewDidAppear : (BOOL) animated
{
   if (!loaded) {
      loaded = YES;
      [self refresh];
   }
}

//________________________________________________________________________________________
- (void) didReceiveMemoryWarning
{
   [super didReceiveMemoryWarning];

   if (!self.photoDownloader.isDownloading) {
      //TODO:!!!
   }
}

//________________________________________________________________________________________
- (void) refresh
{
   if (!photoDownloader.isDownloading) {
      [noConnectionHUD hide : YES];

      [self showSpinner];
      self.navigationItem.rightBarButtonItem.enabled = NO;
      [self.photoDownloader parse];
   }
}

//________________________________________________________________________________________
- (IBAction) reloadImages : (id) sender
{
#pragma unused(sender)

   if (!self.photoDownloader.isDownloading) {
      if (!photoDownloader.hasConnection)
         CernAPP::ShowErrorAlert(@"Please, check network!", @"Close");
      else {
         [self refresh];
      }
   }
}

#pragma mark - UICollectionViewDataSource

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

   UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier : @"PhotoCell" forIndexPath : indexPath];
   assert(!cell || [cell isKindOfClass : [PhotoGridViewCell class]] &&
          "collectionView:cellForItemAtIndexPath:, reusable cell has a wrong type");
   
   if (!cell)
      cell = [[PhotoGridViewCell alloc] initWithFrame : CGRect()];
   
   PhotoGridViewCell * const photoCell = (PhotoGridViewCell *)cell;
   
   assert(indexPath.section >= 0 && indexPath.section < photoSets.count &&
          "collectionView:cellForItemAtIndexPath:, section index is out of bounds");

   PhotoSet * const photoSet = (PhotoSet *)photoSets[indexPath.section];
   
   assert(indexPath.row >= 0 && indexPath.row < photoSet.nImages && "collectionView:cellForItemAtIndexPath:, row index is out of bounds");
   
   photoCell.imageView.image = [photoSet getThumbnailImageForIndex : indexPath.row];
   
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
   assert(indexPath.section < photoSets.count &&
         "collectionView:viewForSupplementaryElementOfKinf:atIndexPath:, indexPath.section is out of bounds");

   UICollectionReusableView *view = nil;

   if ([kind isEqualToString : UICollectionElementKindSectionHeader]) {
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

#pragma mark - UICollectionViewDelegate

//________________________________________________________________________________________
- (void) collectionView : (UICollectionView *) collectionView didSelectItemAtIndexPath : (NSIndexPath *) indexPath
{
   assert(collectionView != nil && "collectionView:didSelectItemAtIndexPath:, parameter 'collectionView' is nil");
   assert(indexPath != nil && "collectionView:didSelectItemAtIndexPath:, parameter 'indexPath' is nil");
   assert(indexPath.section >= 0 && "collectionView:didSelectItemAtIndexPath:, indexPath.section is negative");

   selectedSection = indexPath.section;
   assert(selectedSection < photoSets.count && "collectionView:didSelectItemAtIndexPath:, section is out of bounds");

   MWPhotoBrowser *browser = [[MWPhotoBrowser alloc] initWithDelegate : self];
   browser.displayActionButton = YES;

   [browser setInitialPageIndex : indexPath.row];

   UINavigationController * const navController = [[UINavigationController alloc] initWithRootViewController : browser];
   navController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
   [self presentViewController : navController animated : YES completion : nil];
}


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
   
   [self hideSpinner];
   [self showErrorHUD];
}

//________________________________________________________________________________________
- (void) photoDownloaderDidFinishLoadingThumbnails : (PhotoDownloader *) aPhotoDownloader
{
#pragma unused(aPhotoDownloader)
   [self hideSpinner];
   [photoDownloader compactData];
   photoSets = [photoDownloader.photoSets copy];
   self.navigationItem.rightBarButtonItem.enabled = YES;
   [self.collectionView reloadData];
}

#pragma mark - MWPhotoBrowserDelegate methods

//________________________________________________________________________________________
- (NSUInteger) numberOfPhotosInPhotoBrowser : (MWPhotoBrowser *) photoBrowser
{
#pragma unused(photoBrowser)

   assert(selectedSection < photoSets.count &&
          "numberOfPhotosInPhotoBrowser:, selectedSection is out of bounds");

   PhotoSet * const photoSet = (PhotoSet *)photoSets[selectedSection];

   return photoSet.nImages;
}

//________________________________________________________________________________________
- (MWPhoto *) photoBrowser : (MWPhotoBrowser *) photoBrowser photoAtIndex : (NSUInteger) index
{
#pragma unused(photoBrowser)
   assert(selectedSection < photoSets.count &&
          "photoBrowser:photoAtIndex:, selectedSection is out of bounds");

   PhotoSet * const photoSet = (PhotoSet *)photoSets[selectedSection];
   assert(index < photoSet.nImages && "photoBrowser:photoAtIndex:, index is out of bounds");

   NSURL * const url = [photoSet getImageURLWithIndex : index forType : @"jpgA5"];
   return [MWPhoto photoWithURL : url];
}

//________________________________________________________________________________________
- (void) hudWasTapped : (MBProgressHUD *) hud
{
   [self refresh];
}

#pragma mark - Sliding view.

//________________________________________________________________________________________
- (IBAction) revealMenu : (id) sender
{
#pragma unused(sender)
   [self.slidingViewController anchorTopViewTo : ECRight];
}

#pragma mark - Connection controller.
//________________________________________________________________________________________
- (void) cancelAnyConnections
{
   [photoDownloader stop];
}

#pragma mark - HUD/GUI

//TODO: this must be a category already.

//________________________________________________________________________________________
- (void) showSpinner
{
   if (spinner.hidden)
      spinner.hidden = NO;
   if (!spinner.isAnimating)
      [spinner startAnimating];
}

//________________________________________________________________________________________
- (void) hideSpinner
{
   if (spinner.isAnimating)
      [spinner stopAnimating];
   spinner.hidden = YES;
}

//________________________________________________________________________________________
- (void) showErrorHUD
{
   [MBProgressHUD hideAllHUDsForView : self.view animated : YES];
   noConnectionHUD = [MBProgressHUD showHUDAddedTo : self.view animated : YES];
   noConnectionHUD.delegate = self;
   noConnectionHUD.mode = MBProgressHUDModeText;
   noConnectionHUD.color = [UIColor redColor];
   noConnectionHUD.labelText = @"Network error";
   noConnectionHUD.removeFromSuperViewOnHide = YES;
}

#pragma mark - Interface rotations.

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
