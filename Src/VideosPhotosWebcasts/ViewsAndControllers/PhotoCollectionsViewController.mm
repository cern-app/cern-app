#import <algorithm>

#import "PhotoCollectionsViewController.h"
#import "ECSlidingViewController.h"
#import "PhotoAlbumFooterView.h"
#import "PhotoAlbumCoverView.h"
#import "AnimatedStackLayout.h"
#import "ImageStackViewCell.h"
#import "ApplicationErrors.h"
#import "CDSPhotoAlbum.h"
#import "PhotoViewCell.h"
#import "Reachability.h"
#import "DeviceCheck.h"

using CernAPP::NetworkStatus;

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
   
   NSString *urlString;
   
   //Image downloaders: either thumbnails for a cover view,
   //or album's thumbnails.
   NSMutableDictionary *imageDownloaders;
   NSMutableDictionary *thumbnails;
   NSArray *photoAlbums;

   //Parser-related:
   NSMutableSet *datafieldTags;
   NSMutableSet *subfieldCodes;
   
   NSOperationQueue *parserQueue;
   CDSPhotosParserOperation *operation;

   //Photos manipulation:
   NSIndexPath *selected;     //Index of a selected stack.
   CDSPhotoAlbum *selectedAlbum; //Selected album.

   Reachability *internetReach;
   
   UICollectionView *albumCollectionView;
   UIFont *albumDescriptionCustomFont;//The custom font for a album's description label.
}

@synthesize noConnectionHUD, spinner;

#pragma mark - Network reachability.

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
      noConnectionHUD = nil;
      spinner = nil;
   
      viewDidAppear = NO;
      urlString = nil;

      imageDownloaders = [[NSMutableDictionary alloc] init];
      thumbnails = [[NSMutableDictionary alloc] init];
      photoAlbums = nil;
   
      parserQueue = [[NSOperationQueue alloc] init];
      operation = nil;
      //
      datafieldTags = [[NSMutableSet alloc] init];
      [datafieldTags addObject : @"856"];
      [datafieldTags addObject : @"269"];
      [datafieldTags addObject : @"245"];      
      
      subfieldCodes = [[NSMutableSet alloc] init];
      [subfieldCodes addObject : @"x"];
      [subfieldCodes addObject : @"u"];
      [subfieldCodes addObject : @"c"];
      [subfieldCodes addObject : @"a"];
      //
      selected = nil;
      selectedAlbum = nil;
      
      internetReach = [Reachability reachabilityForInternetConnection];

      albumCollectionView = nil;

      albumDescriptionCustomFont = [UIFont fontWithName : @"PTSans-Bold" size : 24];
      assert(albumDescriptionCustomFont != nil && "initWithCoder:, custom font is nil");
   }

   return self;
}

#pragma mark - viewDid/Done/Does/Will etc.

//________________________________________________________________________________________
- (void) adjustAlbumViewInsets
{
   if (CernAPP::SystemVersionGreaterThanOrEqualTo(@"7.0")) {
      UIEdgeInsets insets = {};
      insets.top = self.navigationController.navigationBar.frame.size.height + 20.f;
      albumCollectionView.contentInset = insets;
   }
}

//________________________________________________________________________________________
- (void) createAlbumViewWithFrame : (CGRect) frame
{
   albumCollectionView = [[UICollectionView alloc] initWithFrame : frame collectionViewLayout : [[AnimatedStackLayout alloc] init]];
   albumCollectionView.hidden = YES;
   albumCollectionView.delegate = self;
   albumCollectionView.dataSource = self;
   //
   albumCollectionView.backgroundColor = [UIColor clearColor];
   //
   [self.view addSubview : albumCollectionView];
   
   [albumCollectionView registerClass : [PhotoViewCell class]
           forCellWithReuseIdentifier : [PhotoViewCell cellReuseIdentifier]];
   [albumCollectionView registerClass: [PhotoAlbumFooterView class]
           forSupplementaryViewOfKind : UICollectionElementKindSectionFooter
                  withReuseIdentifier : [PhotoAlbumFooterView cellReuseIdentifier]];

   albumCollectionView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
                                          UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
                                          UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
   [self adjustAlbumViewInsets];
}

//________________________________________________________________________________________
- (void) viewDidLoad
{
   [super viewDidLoad];
   //
   CernAPP::AddSpinner(self);
   CernAPP::HideSpinner(self);
   
   self.view.backgroundColor = [UIColor blackColor];
   
   [self createAlbumViewWithFrame : CGRect()];
   [self.collectionView.superview bringSubviewToFront : self.collectionView];
   
   [self.collectionView registerClass : [PhotoAlbumCoverView class]
           forCellWithReuseIdentifier : [PhotoAlbumCoverView cellReuseIdentifier]];
}

//________________________________________________________________________________________
- (void) viewWillAppear : (BOOL) animated
{
   [super viewWillAppear : animated];

   [self adjustAlbumViewInsets];
}

//________________________________________________________________________________________
- (void) viewDidAppear : (BOOL) animated
{
   if (!viewDidAppear) {
      viewDidAppear = YES;
      [self refresh];
   }
   
   albumCollectionView.frame = self.collectionView.frame;//TODO: test this!

   if ([self selectedIsValid]) {
      //It's possible, that the device was rotated with photo browser on the top of
      //all views/controllers. In this case, we have to re-adjust a stack center.
      UICollectionViewCell * const cell = [self.collectionView cellForItemAtIndexPath : selected];
      [(AnimatedStackLayout *)albumCollectionView.collectionViewLayout setStackCenterNoUpdate :
         CGPointMake(cell.center.x, cell.center.y - self.collectionView.contentOffset.y)];
   }
}

#pragma mark - Misc. methods.

//________________________________________________________________________________________
- (void) setURLString : (NSString *) anUrlString;
{
   assert(anUrlString != nil && "setURLString:, parameter 'anUrlString' is nil");   
   urlString = anUrlString;
}

#pragma mark - General controller's logic.

//________________________________________________________________________________________
- (void) startParserOperation
{
   assert(urlString != nil && "startParserOperation, urlString is nil");
   assert(parserQueue != nil && "startParserOperation, parserQueue is nil");
   assert(operation == nil && "startParserOperation, parsing operation is still active");
   assert(datafieldTags != nil && "startParserOperation, datafieldTags is nil");
   assert(subfieldCodes != nil && "startParserOperation, subfieldCodes is nil");
   
   operation = [[CDSPhotosParserOperation alloc] initWithURLString : urlString
                                                 datafieldTags : datafieldTags
                                                 subfieldCodes : subfieldCodes];
   
   operation.delegate = self;
   [parserQueue addOperation : operation];
}

//________________________________________________________________________________________
- (void) refresh
{
   assert(urlString != nil && "refresh, urlString is nil");
   assert(parserQueue != nil && "refresh, parserQueue is nil");
   assert(operation == nil && "refresh, called while parsing operation is still active");
   //
   [self cancelAllImageDownloaders];
   //
   [noConnectionHUD hide : YES];
   self.navigationItem.rightBarButtonItem.enabled = NO;//Disable the "Refresh" button.
   CernAPP::ShowSpinner(self);
   [self startParserOperation];
}

#pragma mark - UICollectionViewDelegateFlowLayout
//This delegate, by the way, never explicitly
//mentioned anywhere and even autocomplete does not work
//with this bloody 200-symbols names, remember it by heart, my ass.

//________________________________________________________________________________________
- (CGSize) collectionView : (UICollectionView *) collectionView layout : (UICollectionViewLayout*) collectionViewLayout
           sizeForItemAtIndexPath : (NSIndexPath *) indexPath
{
#pragma unused(collectionViewLayout)

   assert(indexPath != nil && "collectionView:layout:sizeForItemAtIndexPath:, parameter 'indexPath' is nil");

   if (collectionView == albumCollectionView) {
      assert(selectedAlbum != nil &&
             "collectionView:layout:sizeForItemAtIndexPath:, no album was selected");
      assert(indexPath.row < selectedAlbum.nImages &&
             "collectionView:layout:sizeForItemAtIndexPath:, row index is out of bounds");
      
      if (UIImage * const thumbnail = [selectedAlbum getThumbnailImageForIndex : indexPath.row]) {
         const CGSize cellSize = CellSizeFromImageSize(thumbnail.size);
         return cellSize;
      }

      return CGSizeMake(125.f, 125.f);
   }

   //Album's cover has a fixed size.
   return CGSizeMake(200.f, 230.f);
}

//________________________________________________________________________________________
- (CGSize) collectionView : (UICollectionView *) aCollectionView layout : (UICollectionViewLayout*) collectionViewLayout
           referenceSizeForFooterInSection : (NSInteger) section
{
#pragma unsued(collectionLayout)

   assert(aCollectionView != nil &&
          "collectionView:layout:referenceSizeForFooterInSection:, parameter 'aCollectionView' is nil");

   if (aCollectionView == albumCollectionView && selectedAlbum.title.length) {
      assert([collectionViewLayout isKindOfClass:[AnimatedStackLayout class]] &&
             "collectionView:layout:referenceSizeForFooterInSection:, wrong layout type");

      if (((AnimatedStackLayout *)albumCollectionView.collectionViewLayout).inAnimation)
         return CGSize();//There is a bug in a UICollectionView - too many footers are created :(
      
      assert(section == 0 &&
             "collectionView:layout:referenceSizeForFooterInSection:, section is invalid");

      const CGFloat hugeH = 2000.f;
      const CGRect frame = albumCollectionView.frame;
      const CGSize textSize = [selectedAlbum.title sizeWithFont : albumDescriptionCustomFont
                               constrainedToSize : CGSizeMake(frame.size.width, hugeH)];

      return textSize;
   }
   
   return CGSize();
}

//________________________________________________________________________________________
- (CGSize) collectionView : (UICollectionView *) aCollectionView layout : (UICollectionViewLayout*) collectionViewLayout
           referenceSizeForHeaderInSection : (NSInteger) section
{
#pragma unsued(collectionLayout)   
   return CGSize();
}

#pragma mark - UIViewCollectionDataSource

//________________________________________________________________________________________
- (NSInteger) numberOfSectionsInCollectionView : (UICollectionView *) collectionView
{
   if (collectionView == albumCollectionView) {
      if (!selected)//assert?
         return 0;//TODO
    
      return 1;
   }

   if (!photoAlbums)
      return 0;

   return 1;
}

//________________________________________________________________________________________
- (NSInteger) collectionView : (UICollectionView *) collectionView numberOfItemsInSection : (NSInteger) section
{
   if (collectionView == albumCollectionView) {
      if (!selected)//assert?
         return 0;
      
      assert(selectedAlbum != nil &&
             "numberOfSectionsInCollectionView:, no album selected");

      return selectedAlbum.nImages;
   }

   return photoAlbums.count;
}


//________________________________________________________________________________________
- (UICollectionViewCell *) collectionView : (UICollectionView *) collectionView cellForItemAtIndexPath : (NSIndexPath *) indexPath
{
   assert(collectionView != nil && "collectionView:cellForItemAtIndexPath:, parameter 'collectionView' is nil");
   assert(indexPath != nil && "collectionView:cellForItemAtIndexPath:, parameter 'indexPath' is nil");

   if (collectionView == albumCollectionView) {
      UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier : [PhotoViewCell cellReuseIdentifier] forIndexPath : indexPath];
      assert([cell isKindOfClass : [PhotoViewCell class]] && "collectionView:cellForItemAtIndexPath:, reusable cell has a wrong type");
      PhotoViewCell * const photoCell = (PhotoViewCell *)cell;

      if (selectedAlbum) {         
         if (UIImage * const image = [selectedAlbum getThumbnailImageForIndex : indexPath.row])
            photoCell.imageView.image = image;
      }//assert on selectedAlbum == nil?

      return photoCell;
   } else {
      UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier : [PhotoAlbumCoverView cellReuseIdentifier]
                                    forIndexPath : indexPath];
      assert([cell isKindOfClass : [PhotoAlbumCoverView class]] &&
             "collectionView:cellForItemAtIndexPath:, reusable cell has a wrong type");
      PhotoAlbumCoverView * const photoCell = (PhotoAlbumCoverView *)cell;

      assert(indexPath.section >= 0 && indexPath.section < photoAlbums.count &&
             "collectionView:cellForItemAtIndexPath:, section index is out of bounds");

      assert(indexPath.row >= 0 && indexPath.row < photoAlbums.count &&
             "collectionView:cellForItemAtIndexPath:, row index is out of bounds");
      CDSPhotoAlbum * const album = (CDSPhotoAlbum *)photoAlbums[indexPath.row];

      if (UIImage * const image = (UIImage *)thumbnails[indexPath])
         photoCell.imageView.image = image;
      
      if (album.title.length)
         photoCell.title = album.title;

      return photoCell;
   }
}

//________________________________________________________________________________________
- (UICollectionReusableView *) collectionView : (UICollectionView *) aCollectionView
                               viewForSupplementaryElementOfKind : (NSString *) kind atIndexPath : (NSIndexPath *) indexPath
{
   assert(aCollectionView != nil &&
          "collectionView:viewForSupplementaryElementOfKind:atIndexPath:, parameter 'aCollectionView' is nil");
   assert(kind != nil &&
          "collectionView:viewForSupplementaryElementOfKind:atIndexPath:, parameter 'kind' is nil");
   assert(indexPath != nil &&
          "collectionView:viewForSupplementaryElementOfKind:atIndexPath:, parameter 'indexPath' is nil");

   if (aCollectionView == albumCollectionView && [kind isEqualToString : UICollectionElementKindSectionFooter]) {
      //Dequeue
      assert(selectedAlbum != nil &&
            "collectionView:viewForSupplementaryElementOfKind:atIndexPath:, no album is selected");
      assert(indexPath.row < selectedAlbum.nImages &&
            "collectionView:viewForSupplementaryElementOfKind:atIndexPath:, row is out of bounds");
      PhotoAlbumFooterView * const photoCell = (PhotoAlbumFooterView *)[albumCollectionView dequeueReusableSupplementaryViewOfKind : kind
                                                                        withReuseIdentifier : [PhotoAlbumFooterView cellReuseIdentifier]
                                                                        forIndexPath : indexPath];
      if (selectedAlbum.title.length) {
         photoCell.albumDescription.text = selectedAlbum.title;
         photoCell.albumDescription.font = albumDescriptionCustomFont;
      } else
         photoCell.albumDescription.text = @"";
      
      return photoCell;
   }
   
   return nil;
}



#pragma mark - UICollectionView delegate + related methods.

//________________________________________________________________________________________
- (void) collectionView : (UICollectionView *) collectionView didSelectItemAtIndexPath : (NSIndexPath *) indexPath
{
   assert(indexPath != nil && "collectionView:didSelectItemAtIndexPath:, parameter 'indexPath' is nil");
   if (collectionView == albumCollectionView) {
      //Image was selected from an album, open photo browser for this album
      //with the selected image on the visible page.
      assert(selectedAlbum != nil && "collectionView:didSelectItemAtIndexPath:, no album selected");
      assert(indexPath.row >= 0 && indexPath.row < selectedAlbum.nImages &&
             "collectionView:didSelectItemAtIndexPath:, row is out of bounds");
      //Open MWPhotoBrowser.
      MWPhotoBrowser *browser = [[MWPhotoBrowser alloc] initWithDelegate : self];
      browser.displayActionButton = YES;
      [browser setInitialPageIndex : indexPath.row];

      UINavigationController * const navController = [[UINavigationController alloc] initWithRootViewController : browser];
      navController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
      [self presentViewController : navController animated : YES completion : nil];
   } else {
      //Album (stack of images) was selected. Show "un-stack" animation -
      //hide stacked albums and show the selected album contents instead.
      self.navigationItem.rightBarButtonItem.enabled = NO;
      [self swapNavigationBarButtons : NO];//Switch to "Back to albums"
      self.navigationItem.rightBarButtonItem.enabled = NO;//Disable "Back to albums"
   
      //Here's the magic.
      UICollectionViewCell * const cell = [self.collectionView cellForItemAtIndexPath : indexPath];

      assert([albumCollectionView.collectionViewLayout isKindOfClass : [AnimatedStackLayout class]] &&
             "collectionView:didSelectItemAtIndexPath:, albumCollectionView has a wrong layout type");
      AnimatedStackLayout * const layout = (AnimatedStackLayout *)albumCollectionView.collectionViewLayout;
      layout.stackCenter = CGPointMake(cell.center.x, cell.center.y - self.collectionView.contentOffset.y);
      layout.inAnimation = YES;
      layout.stackFactor = 0.f;

      assert(indexPath.row < photoAlbums.count &&
             "collectionView:didSelectItemAtIndexPath:, row is out of bounds");

      selected = indexPath;
      selectedAlbum = (CDSPhotoAlbum *)photoAlbums[indexPath.row];

      [albumCollectionView reloadData];

      self.collectionView.hidden = YES;
      albumCollectionView.hidden = NO;
      [albumCollectionView.superview bringSubviewToFront : albumCollectionView];
      
      [albumCollectionView performBatchUpdates : ^ {
         ((AnimatedStackLayout *)albumCollectionView.collectionViewLayout).stackFactor = 1.f;
      } completion : ^(BOOL finished) {
         if (finished) {
            ((AnimatedStackLayout *)albumCollectionView.collectionViewLayout).inAnimation = NO;
            [albumCollectionView reloadData];//YESSSSSS :(
            self.navigationItem.rightBarButtonItem.enabled = YES;
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
   assert([albumCollectionView.collectionViewLayout isKindOfClass : [AnimatedStackLayout class]] &&
          "switchToStackedMode:, albumCollectionView has a wrong layout type");
   
   AnimatedStackLayout * const layout = (AnimatedStackLayout *)albumCollectionView.collectionViewLayout;

   //Try to hide a footer if any, I do not want to see it during the animation.
   for (UIView *v in albumCollectionView.subviews) {
      if ([v isKindOfClass : [PhotoAlbumFooterView class]])
         v.hidden = YES;
   }

   self.navigationItem.rightBarButtonItem.enabled = NO;//Disable "Back to albums" button (so it can't be pressed more).
   [self swapNavigationBarButtons : YES];//Switch to "Refresh" button.
   self.navigationItem.rightBarButtonItem.enabled = NO; //Disable "Refresh" till the end of animation.

   layout.inAnimation = YES;

   if (selectedAlbum.nImages <= 36)
      self.collectionView.hidden = NO;
   
   [albumCollectionView performBatchUpdates : ^ {
      ((AnimatedStackLayout *)albumCollectionView.collectionViewLayout).stackFactor = 0.f;
   } completion : ^(BOOL finished) {
      if (finished) {
         //Many thanks to Apple for UICollectionView - it somehow manages to create a lot of footer views,
         //which it DOES NOT delete on reloadData, so I have to ... recreate this view to get rid of
         //footers.
         self.collectionView.hidden = NO;
         [albumCollectionView removeFromSuperview];
         [self createAlbumViewWithFrame : self.collectionView.frame];
         [self.collectionView.superview bringSubviewToFront : self.collectionView];

         if (spinner.isAnimating)//Do not forget to show the spinner again, we are still loading.
            [spinner.superview bringSubviewToFront : spinner];

         if (!operation)
            self.navigationItem.rightBarButtonItem.enabled = YES;

         selected = nil;
         selectedAlbum = nil;
      }
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
      NSString *btnTitle = @"Back to albums";
      if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone && CernAPP::SystemVersionGreaterThanOrEqualTo(@"7.0"))
         btnTitle = @"Done";
      self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                                initWithTitle : btnTitle
                                                style :  UIBarButtonItemStyleDone
                                                target : self action : @selector(switchToStackedMode:)];
   }
}

#pragma mark - Interface orientation change.

//________________________________________________________________________________________
- (BOOL) shouldAutorotate
{
   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
      return NO;

   assert(albumCollectionView != nil && "shouldAutorotate, albumCollectionView is nil");
   assert([albumCollectionView.collectionViewLayout isKindOfClass : [AnimatedStackLayout class]] &&
          "shouldAutorotate, albumCollectionView has a wrong layout");
   
   return !((AnimatedStackLayout *)albumCollectionView.collectionViewLayout).inAnimation;
}

//________________________________________________________________________________________
- (void) willAnimateRotationToInterfaceOrientation : (UIInterfaceOrientation) toInterfaceOrientation duration : (NSTimeInterval)duration
{
   assert([self shouldAutorotate] == YES &&
          "willAnimateRotationToInterfaceOrientation:duration:, called while stack animation is active");
   
   if (selected && !albumCollectionView.hidden && [self selectedIsValid]) {
      //We (probably) have to find a new stack center.
      UICollectionViewCell * const cell = [self.collectionView cellForItemAtIndexPath : selected];
      [((AnimatedStackLayout *)albumCollectionView.collectionViewLayout) setStackCenterNoUpdate :
       CGPointMake(cell.center.x, cell.center.y - self.collectionView.contentOffset.y)];
   }
}

#pragma mark - ImageDownloaderDelegate and related methods.

//________________________________________________________________________________________
- (void) loadFirstThumbnails
{
   for (NSUInteger i = 0, e = photoAlbums.count; i < e; ++i) {
      if (((CDSPhotoAlbum *)photoAlbums[i]).nImages)
         [self loadNextThumbnail : [NSIndexPath indexPathForRow : 0 inSection : i]];
      //Else we do not load anything for this album (neither the cover, nor the contents).
   }
}

//________________________________________________________________________________________
- (void) loadNextThumbnail : (NSIndexPath *) indexPath
{
   assert(indexPath != nil && "loadNextThumbnail:, parameter 'indexPath' is nil");
   assert(indexPath.section < photoAlbums.count && "loadNextThumbnail:, section index is out of bounds");

   CDSPhotoAlbum * const album = (CDSPhotoAlbum *)photoAlbums[indexPath.section];
   assert(indexPath.row < album.nImages && "loadNextThumbnail:, row index is out of bounds");

   if (imageDownloaders[indexPath])//Downloading already.
      return;

   ImageDownloader * const downloader = [[ImageDownloader alloc] initWithURL :
                                         [album getImageURLWithIndex : indexPath.row forSize : CernAPP::thumbnailImage]];
   downloader.delegate = self;
   downloader.indexPathInTableView = indexPath;
   [imageDownloaders setObject : downloader forKey : indexPath];
   [downloader startDownload];
}

//________________________________________________________________________________________
- (void) loadThumbnailsForAlbum : (NSUInteger) index
{
   assert(index < photoAlbums.count && "loadThumbnailsForAlbum:, parameter 'index' is out of bounds");
   
   CDSPhotoAlbum * const album = (CDSPhotoAlbum *)photoAlbums[index];
   for (NSUInteger i = 0, e = album.nImages; i < e; ++i) {
      NSIndexPath * const key = [NSIndexPath indexPathForRow : i inSection : index];
      if ([album getThumbnailImageForIndex : i] || imageDownloaders[key])
         continue;
      ImageDownloader * const downloader = [[ImageDownloader alloc] initWithURL :
                                            [album getImageURLWithIndex : i forSize : CernAPP::thumbnailImage]];
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
   assert(indexPath.section < photoAlbums.count &&
          "imageDidLoad:, section index is out of bounds");
   
   CDSPhotoAlbum * const album = (CDSPhotoAlbum *)photoAlbums[indexPath.section];
   assert(indexPath.row < album.nImages && "imageDidLoad:, row index is out of bounds");
   
   ImageDownloader * const downloader = (ImageDownloader *)imageDownloaders[indexPath];
   assert(downloader != nil && "imageDidLoad:, no downloader found for indexPath");
   [imageDownloaders removeObjectForKey : indexPath];

   NSIndexPath * const coverImageKey = [NSIndexPath indexPathForRow : indexPath.section inSection : 0];
   
   if (downloader.image) {
      [album setThumbnailImage : downloader.image withIndex : indexPath.row];
      //Here we have to do some magic:
      
      if (!thumbnails[coverImageKey]) {//We have to update an album's cover.
         [thumbnails setObject : downloader.image forKey : coverImageKey];
         //It's a bit of a mess here - section goes to the row and becomes 0.
         [self.collectionView reloadItemsAtIndexPaths : @[coverImageKey]];
         //Load other thumbnails (not visible in a stacked mode).
         [self loadThumbnailsForAlbum : indexPath.section];
      }
      
      if (selectedAlbum == album) {
         [albumCollectionView reloadItemsAtIndexPaths : @[[NSIndexPath indexPathForRow : indexPath.row inSection : 0]]];
      }
   } else if (!thumbnails[coverImageKey] && indexPath.row + 1 < album.nImages) {
      //We're still trying to download a cover image.
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
   assert(indexPath.section < photoAlbums.count &&
          "imageDownloadFailed:, section index is out of bounds");

   CDSPhotoAlbum * const album = (CDSPhotoAlbum *)photoAlbums[indexPath.section];
   assert(indexPath.row < album.nImages &&
          "imageDownloadFailed:, row index is out of bounds");

   assert(imageDownloaders[indexPath] != nil && "imageDownloadFailed:, no downloader found for indexPath");
   [imageDownloaders removeObjectForKey : indexPath];
   
   NSIndexPath * const coverImageKey = [NSIndexPath indexPathForRow : indexPath.section inSection : 0];
   if (!thumbnails[coverImageKey] && indexPath.row + 1 < album.nImages) {
      //We're still trying to download an album's cover image.
      [self loadNextThumbnail : [NSIndexPath indexPathForRow : indexPath.row + 1 inSection : indexPath.section]];
   }
   
   if (!imageDownloaders.count) {
      self.navigationItem.rightBarButtonItem.enabled = YES;   
      CernAPP::HideSpinner(self);
   }
}

#pragma mark - Parser operation delegate.

//________________________________________________________________________________________
- (void) parserDidFinishWithItems : (NSArray *) items
{
   if (!operation)//Was cancelled.
      return;

   assert(items != nil && "parserDidFinishWithItems:, parameter 'items' is nil");

   operation = nil;
   
   photoAlbums = [items copy];
   [thumbnails removeAllObjects];

   //It's possible, that self.collectionView is hidden now.
   //But anyway - first try to download the first image from
   //every album and set the 'cover', after that, download others.
   //If albumCollectionView is active and visible now, it stil shows data from the selectedAlbum (if any).


   [self loadFirstThumbnails];
   [self.collectionView reloadData];
   
   if (albumCollectionView.hidden)                         //Otherwise, the right item is 'Back to albums'
      self.navigationItem.rightBarButtonItem.enabled = YES;//and it's probably enabled already.
   
   if (!photoAlbums.count)
      CernAPP::HideSpinner(self);
}

//________________________________________________________________________________________
- (void) parserDidFailWithError : (NSError *) error
{
   if (!operation)
      return;

   CernAPP::HideSpinner(self);

   [parserQueue cancelAllOperations];
   operation = nil;

   self.navigationItem.rightBarButtonItem.enabled = YES;
   
   if (!photoAlbums.count)
      CernAPP::ShowErrorHUD(self, @"Network error");
   else
      CernAPP::ShowErrorAlert(@"Please, check network!", @"Close");
}

#pragma mark - ConnectionController delegate and related methods.

//________________________________________________________________________________________
- (void) cancelAllImageDownloaders
{
   if (imageDownloaders.count) {
      @autoreleasepool {
         NSArray * const values = [imageDownloaders allValues];
         for (ImageDownloader *downloader in values)
            [downloader cancelDownload];
      }
   }

   [imageDownloaders removeAllObjects];
}

//________________________________________________________________________________________
- (void) cancelAnyConnections
{
   assert(parserQueue != nil && "cancelAnyConnections, parserQueue is nil");
   [parserQueue cancelAllOperations];
   operation = nil;
   [self cancelAllImageDownloaders];
}

#pragma mark - MWPhotoBrowserDelegate.

//________________________________________________________________________________________
- (NSUInteger) numberOfPhotosInPhotoBrowser : (MWPhotoBrowser *) photoBrowser
{
#pragma unused(photoBrowser)

   assert(selectedAlbum != nil && "numberOfPhotosInPhotoBrowser:, no album selected");
   return selectedAlbum.nImages;
}

//________________________________________________________________________________________
- (MWPhoto *) photoBrowser : (MWPhotoBrowser *) photoBrowser photoAtIndex : (NSUInteger) index
{
#pragma unused(photoBrowser)
   assert(selectedAlbum != nil && "photoBrowser:photoAtIndex:, no album selected");
   assert(index < selectedAlbum.nImages && "photoBrowser:photoAtIndex:, index is out of bounds");

   NSURL * const url = [selectedAlbum getImageURLWithIndex : index forSize : CernAPP::iPadImage];
   return [MWPhoto photoWithURL : url];
}

#pragma mark - UI.

//________________________________________________________________________________________
- (IBAction) reloadImages : (id) sender
{
#pragma unused(sender)
   assert(operation == nil && "reloadImages:, called while parser is still active");
   
   //This method can be called if any previous refresh operation was completed
   //either with a success or a failure (otherwise, refresh button is disabled).
   
   if (![self hasConnection])
      CernAPP::ShowErrorAlert(@"Please, check network!", @"Close");
   else
      [self refresh];
}

#pragma mark - ECSlidingViewController.

//________________________________________________________________________________________
- (IBAction) revealMenu : (id) sender
{
#pragma unused(sender)

   [self.slidingViewController anchorTopViewTo : ECRight];
}

#pragma mark - Aux.

//________________________________________________________________________________________
- (BOOL) selectedIsValid
{
   if (!selected)
      return NO;

   //It can happen, that we:
   //1. pressed refresh button and
   //2. before photo collections were refreshed selected one of loaded albums.
   //3. we are looking at the selected album, but it does not exist after refresh.
   
   return selected.row < photoAlbums.count;
}

@end
