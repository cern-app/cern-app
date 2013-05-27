#import <algorithm>

#import "PhotoCollectionsViewController.h"
#import "ECSlidingViewController.h"
#import "PhotoAlbumFooterView.h"
#import "PhotoAlbumCoverView.h"
#import "AnimatedStackLayout.h"
#import "ImageStackViewCell.h"
#import "ApplicationErrors.h"
#import "PhotoViewCell.h"
#import "Reachability.h"
#import "PhotoAlbum.h"

using CernAPP::ResourceTypeImageForPhotoBrowserIPAD;
using CernAPP::ResourceTypeThumbnail;
using CernAPP::NetworkStatus;

//TODO: This class or a some derived class should also replace a PhotoGridViewController (iPhone version, non-stacked mode).


//TODO: image load logic is weird and must be fixed/clarified.

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
   PhotoAlbum *selectedAlbum;
   
   Reachability *internetReach;
   
   UICollectionView *albumCollectionView;
   UIFont *albumDescriptionCustomFont;//The custom font for a album's description label.
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
      
      //TODO: inform about network error.
      if (!photoAlbumsStatic.count)
         CernAPP::ShowErrorHUD(self, @"Network error");
      else
         CernAPP::ShowErrorAlert(@"Please, check network!", @"Close");
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
      
      selected = nil;
      selectedAlbum = nil;
      
      [[NSNotificationCenter defaultCenter] addObserver : self selector : @selector(reachabilityStatusChanged:) name : CernAPP::reachabilityChangedNotification object : nil];
      internetReach = [Reachability reachabilityForInternetConnection];
      //[internetReach startNotifier];

      albumCollectionView = nil;
      
      albumDescriptionCustomFont = [UIFont fontWithName:@"PTSans-Bold" size : 24];
      assert(albumDescriptionCustomFont != nil && "initWithCoder:, custom font is nil");
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
           forCellWithReuseIdentifier : @"PhotoViewCell"];
   [albumCollectionView registerClass: [PhotoAlbumFooterView class]
           forSupplementaryViewOfKind : UICollectionElementKindSectionFooter
                  withReuseIdentifier : @"PhotoAlbumFooterView"];

   albumCollectionView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
                                          UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
                                          UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
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
   
   [internetReach startNotifier];

   [self.collectionView registerClass : [PhotoAlbumCoverView class]
           forCellWithReuseIdentifier : @"PhotoAlbumCoverView"];
   

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
      UICollectionViewCell * const cell = [self.collectionView cellForItemAtIndexPath : selected];
      [(AnimatedStackLayout *)albumCollectionView.collectionViewLayout setStackCenterNoUpdate :
         CGPointMake(cell.center.x, cell.center.y - self.collectionView.contentOffset.y)];
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
      [self cancelAllImageDownloaders];//TODO: test, can any of them be active if I can refresh??
      //
      [noConnectionHUD hide : YES];
      self.navigationItem.rightBarButtonItem.enabled = NO;
      CernAPP::ShowSpinner(self);
      [parser parse];
   }
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
         return CGSize();
      
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
      
      assert(selectedAlbum != nil &&
             "numberOfSectionsInCollectionView:, no album selected");

      return selectedAlbum.nImages;
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
      if (selectedAlbum) {         
         if (UIImage * const image = [selectedAlbum getThumbnailImageForIndex : indexPath.row])
            photoCell.imageView.image = image;
      }//assert on selectedAlbum == nil?

      return photoCell;
   } else {
      UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier : @"PhotoAlbumCoverView" forIndexPath : indexPath];
      assert(!cell || [cell isKindOfClass : [PhotoAlbumCoverView class]] &&
             "collectionView:cellForItemAtIndexPath:, reusable cell has a wrong type");
      
      if (!cell) {
         //TODO
      }
      
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
      UICollectionViewCell *cell = [albumCollectionView dequeueReusableSupplementaryViewOfKind : kind
                                                                           withReuseIdentifier : @"PhotoAlbumFooterView"
                                                                                  forIndexPath : indexPath];
      assert(!cell || [cell isKindOfClass : [PhotoAlbumFooterView class]] &&
             "collectionView:viewForSupplementaryElementOfKind:atIndexPath:, no album is selected");
      
      if (!cell) {
         //TODO
      }
      
      PhotoAlbumFooterView * const photoCell = (PhotoAlbumFooterView *)cell;
      if (selectedAlbum.title.length) {
         photoCell.albumDescription.text = selectedAlbum.title;
         photoCell.albumDescription.font = albumDescriptionCustomFont;
      } else
         photoCell.albumDescription.text = @"";
      
      return cell;
   }
   
   return nil;
}



#pragma mark - UICollectionView delegate + related methods.

//________________________________________________________________________________________
- (void) collectionView : (UICollectionView *) collectionView didSelectItemAtIndexPath : (NSIndexPath *) indexPath
{
   assert(indexPath != nil && "collectionView:didSelectItemAtIndexPath:, parameter 'indexPath' is nil");

   if (collectionView == albumCollectionView) {
      assert(selectedAlbum != nil && "collectionView:didSelectItemAtIndexPath:, no album selected");
      assert(indexPath.row < selectedAlbum.nImages && "collectionView:didSelectItemAtIndexPath:, row is out of bounds");
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

      assert([albumCollectionView.collectionViewLayout isKindOfClass : [AnimatedStackLayout class]] &&
             "collectionView:didSelectItemAtIndexPath:, albumCollectionView has a wrong layout type");
      AnimatedStackLayout * const layout = (AnimatedStackLayout *)albumCollectionView.collectionViewLayout;
      layout.stackCenter = CGPointMake(cell.center.x, cell.center.y - self.collectionView.contentOffset.y);
      layout.inAnimation = YES;
      layout.stackFactor = 0.f;

      assert(indexPath.row < photoAlbumsStatic.count &&
             "collectionView:didSelectItemAtIndexPath:, row is out of bounds");

      selected = indexPath;
      selectedAlbum = (PhotoAlbum *)photoAlbumsStatic[indexPath.row];

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
            [self swapNavigationBarButtons : NO];
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

   self.navigationItem.rightBarButtonItem.enabled = NO;
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

         [self swapNavigationBarButtons : YES];
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
      self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                                initWithTitle : @"Back to albums" style : UIBarButtonItemStyleDone
                                                target : self action : @selector(switchToStackedMode:)];
   }
}

#pragma mark - Interface orientation change.

//________________________________________________________________________________________
- (BOOL) shouldAutorotate
{
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

   if (imageDownloaders[indexPath])//Downloading already.
      return;

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
   assert(indexPath.section < photoAlbumsStatic.count &&
          "imageDownloadFailed:, section index is out of bounds");

   PhotoAlbum * const album = (PhotoAlbum *)photoAlbumsStatic[indexPath.section];
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
   photoAlbumsStatic = [photoAlbumsDynamic mutableCopy];
   [thumbnails removeAllObjects];
   
   //It's possible, that self.collectionView is hidden now.
   //But anyway - first try to download the first image from
   //every album and set the 'cover', after that, download others.
   //If albumCollectionView is active and visible now, it stil shows data from the selectedAlbum (if any).
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

   assert(selectedAlbum != nil && "numberOfPhotosInPhotoBrowser:, no album selected");
   return selectedAlbum.nImages;
}

//________________________________________________________________________________________
- (MWPhoto *) photoBrowser : (MWPhotoBrowser *) photoBrowser photoAtIndex : (NSUInteger) index
{
#pragma unused(photoBrowser)
   assert(selectedAlbum != nil && "photoBrowser:photoAtIndex:, no album selected");
   assert(index < selectedAlbum.nImages && "photoBrowser:photoAtIndex:, index is out of bounds");

   NSURL * const url = [selectedAlbum getImageURLWithIndex : index forType : ResourceTypeImageForPhotoBrowserIPAD];
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
   
   return selected.row < photoAlbumsStatic.count;
}

@end
