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
#import "AppDelegate.h"

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

//We do not start all image downloaders at once, but
//in small "bursts" (to avoid terrible number of backgroudn threads).
const NSUInteger burstSize = 5;

enum class AnimationState : unsigned char {
   none,
   unstack,
   stack,
   reload,
   browsing
};

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
   
   NSURLConnection *CDSconnection;
   NSMutableData *xmlData;
   NSOperationQueue *parserQueue;
   CDSPhotosParserOperation *operation;

   //Photos manipulation:
   NSIndexPath *selected;     //Index of a selected stack.
   CDSPhotoAlbum *selectedAlbum; //Selected album.

   Reachability *internetReach;

   //We load images in short "bursts", album by album.
   NSUInteger coversToLoad;
   NSIndexPath *lastThumbnailPath;
   
   UICollectionView *albumCollectionView;
   UIFont *albumDescriptionCustomFont;//The custom font for a album's description label.
   
   NSMutableArray *delayedReload;//Indices for items to be reloaded later.
   AnimationState animationState;
}

@synthesize cacheID, noConnectionHUD, spinner;

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
   
      CDSconnection = nil;
      xmlData = nil;
      parserQueue = [[NSOperationQueue alloc] init];
      operation = nil;
      //
      datafieldTags = [[NSMutableSet alloc] init];
      [datafieldTags addObject : CernAPP::CDStagMARC];
      [datafieldTags addObject : CernAPP::CDStagDate];
      [datafieldTags addObject : CernAPP::CDStagTitle];
      [datafieldTags addObject : CernAPP::CDStagTitleAlt];
      
      subfieldCodes = [[NSMutableSet alloc] init];
      [subfieldCodes addObject : CernAPP::CDScodeContent];
      [subfieldCodes addObject : CernAPP::CDScodeURL];
      [subfieldCodes addObject : CernAPP::CDScodeDate];
      [subfieldCodes addObject : CernAPP::CDScodeTitle];
      //
      selected = nil;
      selectedAlbum = nil;
      
      internetReach = [Reachability reachabilityForInternetConnection];

      coversToLoad = 0;
      lastThumbnailPath = nil;

      albumCollectionView = nil;

      albumDescriptionCustomFont = [UIFont fontWithName : @"PTSans-Bold" size : 24];
      assert(albumDescriptionCustomFont != nil && "initWithCoder:, custom font is nil");
      
      delayedReload = [[NSMutableArray alloc] init];
      animationState = AnimationState::none;
   }

   return self;
}

//________________________________________________________________________________________
- (void) dealloc
{
   [self cancelAnyConnections];
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
   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
      CernAPP::AddCustomSpinner(self);
   else
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
- (BOOL) initFromAppCache
{
   assert([[UIApplication sharedApplication].delegate isKindOfClass : [AppDelegate class]] &&
          "initFromAppCache, app delegate is nil or has a wrong type");

   if (!cacheID)
      return NO;

   AppDelegate * const appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
   if ((photoAlbums = (NSArray *)[appDelegate cacheForKey : cacheID])) {
      //
      CernAPP::ShowSpinner(self);
      [self loadThumbnailsFromCache];
      [self.collectionView reloadData];
      //
      return YES;
   }

   return NO;
}

//________________________________________________________________________________________
- (void) viewDidAppear : (BOOL) animated
{
   if (!viewDidAppear) {
      viewDidAppear = YES;
      
      if (![self initFromAppCache])
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
   assert(CDSconnection == nil && "startParserOperation, CDS connection is still active");
   assert(operation == nil && "startParserOperation, parsing operation is still active");
   
   if (NSURL * const url = [NSURL URLWithString : urlString]) {
      if (NSURLRequest * const request = [NSURLRequest requestWithURL : url]) {
         xmlData = [[NSMutableData alloc] init];
         if ((CDSconnection = [[NSURLConnection alloc] initWithRequest : request delegate : self]))
            return;
         xmlData = nil;
      }
   }

   [self handleNetworkError : nil];
}

//________________________________________________________________________________________
- (void) refresh
{
   assert(urlString != nil && "refresh, urlString is nil");
   assert(CDSconnection == nil && "refresh, called while CDS connection is still active");
   assert(parserQueue != nil && "refresh, parserQueue is nil");
   assert(operation == nil && "refresh, called while parsing operation is still active");
   //
   [self cancelAllImageDownloaders];
   //
   [noConnectionHUD hide : YES];

   if (albumCollectionView.hidden) //Is it possible to view an album view and press 'refresh'???
      self.navigationItem.rightBarButtonItem.enabled = NO;

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
   //For album collection view we always return 1, even if there is no items at the moment
   //in this section: albumCollectionView has quite a lot of animations to work with,
   //and I have to somehow make them mutually exclusive, so I have to use performBatchUpdate +
   //its completion block (which is the most important part actually). But for performBatchUpdate
   //there are some condition checks - number of sections/rows before update and after update must
   //be consistent (number of section before +- insert/delete == number of sections after, the same for rows).
   //I do not insert rows, I'm reloading the only section I have.

   if (collectionView == albumCollectionView)
      return 1;

   if (!photoAlbums)
      return 0;

   return 1;
}

//________________________________________________________________________________________
- (NSInteger) collectionView : (UICollectionView *) collectionView numberOfItemsInSection : (NSInteger) section
{
#pragma unused(section)
   assert(collectionView != nil && "collectionView:numberOfItemsInSection:, parameter 'collectionView' is nil");

   if (collectionView == albumCollectionView) {
      if (!selected)
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
      UICollectionViewCell * const cell = [collectionView dequeueReusableCellWithReuseIdentifier :
                                           [PhotoViewCell cellReuseIdentifier] forIndexPath : indexPath];
      assert([cell isKindOfClass : [PhotoViewCell class]] &&
             "collectionView:cellForItemAtIndexPath:, reusable cell has a wrong type");

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
- (void) reloadItemsInUnstackedCollectionView
{
   assert(albumCollectionView.hidden == NO && "reloadItemsInUnstackedCollectionView, collection view is hidden");
   assert(animationState != AnimationState::stack && "reloadItemsInUnstackedCollectionView, invalid animation type");
   assert(delayedReload != nil && "reloadItemsInUnstackedCollectionView, delayedReload is not initialized");

   if (delayedReload.count) {
      animationState = AnimationState::reload;
      NSArray * const cp = [delayedReload copy];
      [delayedReload removeAllObjects];

      [albumCollectionView performBatchUpdates : ^ {
         [albumCollectionView reloadItemsAtIndexPaths : cp];
       } completion: ^ (BOOL finished) {
         if (finished)//May be, we already have MORE items to reload.
            [self reloadItemsInUnstackedCollectionView];
      }];
   } else {
      animationState = AnimationState::none;
      if (self.navigationItem.rightBarButtonItem.enabled == NO)
         self.navigationItem.rightBarButtonItem.enabled = YES;//"Back to albums" button.
   }
}

//________________________________________________________________________________________
- (void) updateUnstackedCollectionView
{
   assert(albumCollectionView.hidden == NO && "updateUnstackedCollectionView, collection view is hidden");
   assert(animationState != AnimationState::stack && "updateUnstackedCollectionView, invalid animation type");
   assert(delayedReload != nil && "updateUnstackedCollectionView, delayedReload is not initialized");

   animationState = AnimationState::reload;
   [delayedReload removeAllObjects];//I'm going to reload the view completely.
      
   [albumCollectionView performBatchUpdates : ^ {
      [albumCollectionView reloadData];
   } completion: ^ (BOOL finished) {
      if (finished)//May be, we already have MORE items to reload.
         [self reloadItemsInUnstackedCollectionView];
   }];
}


//________________________________________________________________________________________
- (void) collectionView : (UICollectionView *) collectionView didSelectItemAtIndexPath : (NSIndexPath *) indexPath
{
   if (animationState != AnimationState::none)
      //Ignore, some animation is already active.
      return;

   assert(indexPath != nil && "collectionView:didSelectItemAtIndexPath:, parameter 'indexPath' is nil");

   if (collectionView == albumCollectionView) {
      animationState = AnimationState::browsing;
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
      //Unless an animation finished, ignore every other interaction.
      animationState = AnimationState::unstack;
      //
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

      //1. Reload albumCollectionView (it had 0 items before).
      //I can not do this using reloadData, since I want to know exactly when
      //the animation finishes - to enable GUI interactions back.

      [albumCollectionView performBatchUpdates: ^ {
         [albumCollectionView reloadSections : [NSIndexSet indexSetWithIndex : 0]];
       } completion : ^(BOOL finished) {
         if (finished) {
            self.collectionView.hidden = YES;
            albumCollectionView.hidden = NO;
            [albumCollectionView.superview bringSubviewToFront : albumCollectionView];
         
            [albumCollectionView performBatchUpdates : ^ {
               ((AnimatedStackLayout *)albumCollectionView.collectionViewLayout).stackFactor = 1.f;
            } completion : ^(BOOL finished) {
               if (finished) {
                  ((AnimatedStackLayout *)albumCollectionView.collectionViewLayout).inAnimation = NO;
                  //It's possible, that during 'unstack' animation some items were loaded -
                  //now refresh them in the albumCollection view (if any).
                  [self reloadItemsInUnstackedCollectionView];
               }
            }];
         }
       }
      ];
   }
}

//________________________________________________________________________________________
- (void) switchToStackedMode : (id) sender
{
#pragma unused(sender)
   
   if (animationState != AnimationState::none)
      //Ignore, still some animation is active.
      return;

   animationState = AnimationState::stack;
   [delayedReload removeAllObjects];

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
         else
            self.navigationItem.rightBarButtonItem.enabled = YES;

         animationState = AnimationState::none;
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

#pragma mark - NSURLConnectionDataDelegate and related methods.

//________________________________________________________________________________________
- (void) connection : (NSURLConnection *) connection didReceiveData : (NSData *) data
{
#pragma unused(connection)

   assert(data != nil && "connection:didReceiveData:, parameter 'data' is nil");
   assert(xmlData != nil && "connection:didReceiveData:, xmlData is nil");
   
   [xmlData appendData : data];
}

//________________________________________________________________________________________
- (void) connection : (NSURLConnection *) connection didFailWithError : (NSError *) error
{
#pragma unused(connection)
   xmlData = nil;
   [CDSconnection cancel];
   CDSconnection = nil;
   [self handleNetworkError : error];
}

//________________________________________________________________________________________
- (void) connectionDidFinishLoading : (NSURLConnection *) connection
{
   assert(xmlData != nil && "connectionDidFinishLoading:, xmlData is nil");
   assert(operation == nil && "connectionDidFinishLoading:, called while parsing operation is active");
   assert(parserQueue != nil && "connectionDidFinishLoading:, parserQueue is nil");
   
   CDSconnection = nil;

   if (xmlData.length) {
      operation = [[CDSPhotosParserOperation alloc] initWithXMLData : xmlData
                                                    datafieldTags : datafieldTags
                                                    subfieldCodes : subfieldCodes];
      operation.delegate = self;
      [parserQueue addOperation : operation];
      xmlData = nil;
   } else {
      xmlData = nil;
      [self handleNetworkError : nil];
   }
}

#pragma mark - Thubmnails (aux. methods and ImageDownloaderDelegate)

//________________________________________________________________________________________
- (void) allImagesDidLoad
{
   if (albumCollectionView.hidden)                         //Otherwise, the right item is 'Back to albums'
      self.navigationItem.rightBarButtonItem.enabled = YES;//and it's probably enabled already.

   CernAPP::HideSpinner(self);
}

//1. "Top-level" functions.

//________________________________________________________________________________________
- (void) loadThumbnailsFromCache
{
   //We have some data in the app's "runtime cache".
   //If there are some images in this cache - use them as collections' covers,
   //download thumbnails if not and hide spinner if no downloaders created at the end.
   
   assert(photoAlbums != nil && "loadThumbnailsFromCache, photoAlbums is nil");
   assert(thumbnails != nil && "loadThumbnailsFromCache, thumbnails is nil");

   if (!photoAlbums.count)//A strange cache, but why not?
      return [self allImagesDidLoad];

   assert(imageDownloaders != nil && "loadThumbnailsFromCache, imageDownloaders is nil");
   assert(imageDownloaders.count == 0 &&
          "loadThumbnailsFromCache, called while some downloader(s) is still active");

   [thumbnails removeAllObjects];
   lastThumbnailPath = nil;
   coversToLoad = photoAlbums.count;

   //1. Start from the "cover" images for our collections.
   for (NSUInteger i = 0, e = photoAlbums.count; i < e; ++i) {
      CDSPhotoAlbum * const album = (CDSPhotoAlbum *)photoAlbums[i];
      NSUInteger imageToLoad = 0;
      bool coverFound = false, linkFound = false;
      for (NSUInteger j = 0, e1 = album.nImages; j < e1; ++j) {
         if (UIImage * const image = [album getThumbnailImageForIndex : j]) {
            thumbnails[[NSIndexPath indexPathForRow : i inSection : 0]] = image;
            coverFound = true;
            --coversToLoad;
            break;
         } else if ([album getImageURLWithIndex : j urlType : CernAPP::thumbnailImageUrl] && !linkFound) {
            imageToLoad = j;
            linkFound = true;
         }
      }

      if (!coverFound && linkFound)
         //Ooops, no images in cache, try to load.
         [self addThumbnailDownloader : [NSIndexPath indexPathForRow : imageToLoad inSection : i]];
   }

   if (!imageDownloaders.count) {//We found images for all "covers" in the cache.
      //We either found all covers or some of them (or none and no valid urls),
      coversToLoad = 0;
      [self loadNextRange];//Download other thumbnails if needed.
   } else
      [self startThumbnailDownloaders];
}

//________________________________________________________________________________________
- (void) loadThumbnails
{
   assert(thumbnails != nil && "loadThubmnails, thumbnails is nil");
   assert(photoAlbums != nil && "loadThumbnails, photoAlbums is nil");

   if (!photoAlbums.count)
      return [self allImagesDidLoad];
   
   assert(imageDownloaders != nil && "loadThumbnails, imageDownloaders is nil");
   assert(imageDownloaders.count == 0 &&
          "loadThumbnails, called while some downloader(s) still active");

   //We start from the "cover" images for our collections.
   [thumbnails removeAllObjects];
   lastThumbnailPath = nil;
   coversToLoad = photoAlbums.count;
   
   for (NSUInteger i = 0, e = photoAlbums.count; i < e; ++i) {
      CDSPhotoAlbum * const album = (CDSPhotoAlbum *)photoAlbums[i];
      for (NSUInteger j = 0, e1 = album.nImages; j < e1; ++j) {
         if ([album getImageURLWithIndex : j urlType:CernAPP::thumbnailImageUrl]) {
            [self addThumbnailDownloader : [NSIndexPath indexPathForRow : j inSection : i]];
            break;//continue with a next collection.
         }
      }
   }

   if (!imageDownloaders.count) {
      coversToLoad = 0;          //No valid URL was found for any cover, so no valid url can be found at all ...
      [self allImagesDidLoad];   //... vse propalo, shef, vse propalo!!!
   } else
      [self startThumbnailDownloaders];
}

//2. "Low-level workers" functions.

//________________________________________________________________________________________
- (void) loadThumbnail : (NSIndexPath *) indexPath
{
   assert(indexPath != nil && "loadThumbnail:, parameter 'indexPath' is nil");
   assert(photoAlbums != nil && "loadThumbnail:, photoAlbums is nil");
   assert(indexPath.section < photoAlbums.count && "loadThumbnail:, section index is out of bounds");
   
   assert(imageDownloaders != nil && "loadThumbnail:, imageDownloaders is nil");
   if (imageDownloaders[indexPath])//Downloading already.
      return;

   CDSPhotoAlbum * const album = (CDSPhotoAlbum *)photoAlbums[indexPath.section];
   assert(indexPath.row < album.nImages && "loadThumbnail:, row index is out of bounds");
   
   if (NSURL * const thumbnailUrl = [album getImageURLWithIndex : indexPath.row urlType : CernAPP::thumbnailImageUrl]) {
      ImageDownloader * const downloader = [[ImageDownloader alloc] initWithURL : thumbnailUrl];
      downloader.delegate = self;
      downloader.indexPathInTableView = indexPath;
      [imageDownloaders setObject : downloader forKey : indexPath];
      [downloader startDownload];
   }
}

//________________________________________________________________________________________
- (void) addThumbnailDownloader : (NSIndexPath *) indexPath
{
   //Add a downloader but do not start download (it'll be done somewhere else).
   assert(indexPath != nil && "addThumbnailDownloader:, parameter 'indexPath' is nil");
   assert(photoAlbums != nil && "addThumbnailDownloader:, photoAlbums is nil");
   assert(indexPath.section < photoAlbums.count && "addThumbnailDownloader:, section index is out of bounds");

   CDSPhotoAlbum * const album = (CDSPhotoAlbum *)photoAlbums[indexPath.section];
   assert(indexPath.row >= 0 && indexPath.row < NSInteger(album.nImages) && "addThumbnailDownloader:, row index is out of bounds");

   assert(imageDownloaders != nil && "addThumbnailDownloader:, imageDownloaders is nil");
   if (imageDownloaders[indexPath])//Downloading already.
      return;

   if (NSURL * const thumbnailUrl = [album getImageURLWithIndex : indexPath.row urlType : CernAPP::thumbnailImageUrl]) {
      ImageDownloader * const downloader = [[ImageDownloader alloc] initWithURL : thumbnailUrl];
      downloader.delegate = self;
      downloader.indexPathInTableView = indexPath;
      [imageDownloaders setObject : downloader forKey : indexPath];
      //This new downloader is not started yet.
   }
}

//________________________________________________________________________________________
- (void) startThumbnailDownloaders
{
   assert(imageDownloaders != nil && "startThumbnailDownloaders, imageDownloaders is nil");

   if (imageDownloaders.count) {
      @autoreleasepool {
         NSArray * const values = [imageDownloaders allValues];
         for (ImageDownloader *downloader in values)
            [downloader startDownload];
      }
   }
}

//________________________________________________________________________________________
- (void) loadNextRange
{
   assert(photoAlbums != nil && "loadNextRange, photoAlbums is nil");
   assert(photoAlbums.count != 0 && "loadNextRange, no albums found");
   assert(imageDownloaders != nil && "loadNextRange, imageDownloaders is nil");
   assert(imageDownloaders.count == 0 &&
          "loadNextRange, called while some downloaders are still active");
   assert((lastThumbnailPath == nil ||
           (lastThumbnailPath.section >= 0 && lastThumbnailPath.section < NSInteger(photoAlbums.count))) &&
          "loadNextRange, lastThumbnailPath is invalid");

   NSUInteger currAlbum = 0;
   NSUInteger currImage = 0;
   if (lastThumbnailPath) {
      CDSPhotoAlbum * const ca = (CDSPhotoAlbum *)photoAlbums[lastThumbnailPath.section];
      assert(lastThumbnailPath.row >= 0 && lastThumbnailPath.row < NSInteger(ca.nImages) &&
             "loadNextRange, lastThumbnailPath is invalid");
      if (lastThumbnailPath.row + 1 < NSInteger(ca.nImages)) {
         currAlbum = lastThumbnailPath.section;
         currImage = lastThumbnailPath.row + 1;
      } else
         currAlbum = lastThumbnailPath.section + 1;
   }

   if (currAlbum == photoAlbums.count) {
      [self allImagesDidLoad];
      return;
   }
   
   NSUInteger nNew = 0;
   for (NSUInteger e = photoAlbums.count; currAlbum < e && nNew < burstSize; ++currAlbum) {
      
      CDSPhotoAlbum * const ca = (CDSPhotoAlbum *)photoAlbums[currAlbum];
      for (NSUInteger e1 = ca.nImages; currImage < e1 && nNew < burstSize; ++currImage) {
         if ([ca getThumbnailImageForIndex : currImage])
            continue;//We have thumbnail already, skip.
         if (![ca getImageURLWithIndex : currImage urlType : CernAPP::thumbnailImageUrl])
            continue;//We have no previously downloaded thumbnail and no url.

         lastThumbnailPath = [NSIndexPath indexPathForRow : currImage inSection : currAlbum];
         [self addThumbnailDownloader : lastThumbnailPath];
         
         ++nNew;
      }
      currImage = 0;
   }
   
   if (imageDownloaders.count)
      [self startThumbnailDownloaders];
   else
      [self allImagesDidLoad];
}

//3. ImageDownloaderDelegate - work for both "covers" and thumbnails (and also for failed images).

//________________________________________________________________________________________
- (void) tryToReloadItem : (NSIndexPath *) indexPath
{
   assert(indexPath != nil && "tryToReloadItem:, parameter 'indexPath' is invalid");
   assert(indexPath.section >= 0 && indexPath.section < NSInteger(photoAlbums.count) &&
          "tryToReloadItem:, section index is out of bounds");

   CDSPhotoAlbum * const album = (CDSPhotoAlbum *)photoAlbums[indexPath.section];
   assert(indexPath.row >= 0 && indexPath.row < NSInteger(album.nImages) &&
          "tryToReloadItem:, row index is out of bounds");
   
   if (selectedAlbum != album)
      return;
   
   if (animationState == AnimationState::none) {
      [delayedReload addObject : [NSIndexPath indexPathForRow : indexPath.row inSection : 0]];
      [self reloadItemsInUnstackedCollectionView];
   } else if (animationState != AnimationState::stack) {//Nothing to reload if animating back to a 'stack'.
      //We're already in animation, postpone the update.
      [delayedReload addObject : [NSIndexPath indexPathForRow : indexPath.row inSection : 0]];
   }
}

//________________________________________________________________________________________
- (void) imageDidLoad : (NSIndexPath *) indexPath
{
   assert(photoAlbums != nil && "imageDidLoad:, photoAlbums is nil");
   assert(indexPath != nil && "imageDidLoad:, parameter 'indexPath' is nil");
   assert(indexPath.section >= 0 && indexPath.section < NSInteger(photoAlbums.count) &&
          "imageDidLoad:, section index is out of bounds");

   CDSPhotoAlbum * const album = (CDSPhotoAlbum *)photoAlbums[indexPath.section];
   assert(indexPath.row >= 0 && indexPath.row < NSInteger(album.nImages) &&
          "imageDidLoad:, row index is out of bounds");

   ImageDownloader * const downloader = (ImageDownloader *)imageDownloaders[indexPath];
   assert(downloader != nil && "imageDidLoad:, no downloader found for indexPath");
   [imageDownloaders removeObjectForKey : indexPath];

   if (coversToLoad) {//We were still downloading "covers".
      if (downloader.image) {
         assert(thumbnails != nil && "imageDidLoad:, thumbnails is nil");
         NSIndexPath * const coverImageKey = [NSIndexPath indexPathForRow : indexPath.section inSection : 0];
         [album setThumbnailImage : downloader.image withIndex : indexPath.row];
         [thumbnails setObject : downloader.image forKey : coverImageKey];
         //It's a bit of a mess here - section goes to the row and becomes 0.
         [self.collectionView reloadItemsAtIndexPaths : @[coverImageKey]];
      
         if (selectedAlbum == album)
            [self tryToReloadItem : indexPath];
      } else {//Ooops, try next url if any.
         for (NSInteger i = indexPath.row + 1, e = NSInteger(album.nImages); i < e; ++i) {
            if ([album getImageURLWithIndex : i urlType : CernAPP::thumbnailImageUrl]) {//We continue.
               [self loadThumbnail : [NSIndexPath indexPathForRow : i inSection : indexPath.section]];
               return;
            }
         }
      }
   
      if (!--coversToLoad)
         [self loadNextRange];
      //Else we do nothing here, somebody else will do later.
   } else {
      if (downloader.image) {
         [album setThumbnailImage : downloader.image withIndex : indexPath.row];
         if (selectedAlbum == album)
            [self tryToReloadItem : indexPath];
      }

      if (!imageDownloaders.count)
         [self loadNextRange];
   }
}

//________________________________________________________________________________________
- (void) imageDownloadFailed : (NSIndexPath *) indexPath
{
   assert(photoAlbums != nil && "imageDownloadFailed:, photoAlbums is nil");
   assert(indexPath != nil && "imageDownloadFailed:, parameter 'indexPath' is nil");
   assert(indexPath.section >= 0 && indexPath.section < NSInteger(photoAlbums.count) &&
          "imageDownloadFailed:, section index is out of bounds");

   CDSPhotoAlbum * const album = (CDSPhotoAlbum *)photoAlbums[indexPath.section];
   assert(indexPath.row >= 0 && indexPath.row < NSInteger(album.nImages) &&
          "imageDownloadFailed:, row index is out of bounds");

   ImageDownloader * const failed = imageDownloaders[indexPath];
   assert(failed != nil && "imageDownloadFailed:, no downloader found for indexPath");
   
   //Hehe, imageDidLoad: handles the case of downloader.image == nil,
   //no need to duplicate the code.
   //downloader is not removed here - to be done in imageDidLoad:.
   failed.image = nil;
   [self imageDidLoad : indexPath];
}

#pragma mark - Parser operation delegate and related methods.

//________________________________________________________________________________________
- (void) handleNetworkError : (NSError *) error
{
#pragma unused(error)
   //TODO: log the 'error'?
   [parserQueue cancelAllOperations];
   operation = nil;
   
   [self resetControls];
   
   if (!photoAlbums.count)
      CernAPP::ShowErrorHUD(self, @"Network error");
   else
      CernAPP::ShowErrorAlert(@"Please, check network!", @"Close");
}

//________________________________________________________________________________________
- (void) resetControls
{
   CernAPP::HideSpinner(self);
   if (albumCollectionView.hidden)
      self.navigationItem.rightBarButtonItem.enabled = YES;
}

//________________________________________________________________________________________
- (void) parserDidFinishWithItems : (NSArray *) items
{
   if (!operation)//Was cancelled.
      return;

   assert(items != nil && "parserDidFinishWithItems:, parameter 'items' is nil");

   operation = nil;
   
   photoAlbums = [items copy];
   //
   if (cacheID) {
      assert([[UIApplication sharedApplication].delegate isKindOfClass : [AppDelegate class]] &&
             "parserDidFinishWithItems:, app delegate is either nil or has a wrong type");
      [(AppDelegate *)[UIApplication sharedApplication].delegate cacheData : photoAlbums withKey : cacheID];
   }
   //
   [thumbnails removeAllObjects];

   //It's possible, that self.collectionView is hidden now.
   //But anyway - first try to download the first image from
   //every album and set the 'cover', after that, download others.
   //If albumCollectionView is active and visible now, it stil shows data from the selectedAlbum (if any).
   [self loadThumbnails];
   [self.collectionView reloadData];
}

//________________________________________________________________________________________
- (void) parserDidFailWithError : (NSError *) error
{
   if (!operation)
      return;

   [parserQueue cancelAllOperations];
   operation = nil;

   //I can not show any error message - it's useless for an user:(
   //Just hide activity indicators and enable 'refresh' button.
   NSLog(@"PhotoCollectionsViewController<error>: -parserDidFailedWithError: was called with error %@", error);
   [self resetControls];
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
   lastThumbnailPath = nil;
   coversToLoad = 0;   
}

//________________________________________________________________________________________
- (void) cancelAnyConnections
{
   assert(parserQueue != nil && "cancelAnyConnections, parserQueue is nil");

   if (CDSconnection)
      [CDSconnection cancel];
   
   CDSconnection = nil;
   [parserQueue cancelAllOperations];
   operation = nil;
   [self cancelAllImageDownloaders];
}

#pragma mark - MWPhotoBrowserDelegate.

//________________________________________________________________________________________
- (void) photoBrowserWillDismiss
{
   if (animationState == AnimationState::browsing)
      animationState = AnimationState::none;
}

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

   NSURL * const url = [selectedAlbum getImageURLWithIndex : index urlType : CernAPP::iPadImageUrl];
   return [MWPhoto photoWithURL : url];
}

#pragma mark - UI.

//________________________________________________________________________________________
- (IBAction) reloadImages : (id) sender
{
#pragma unused(sender)
   if (animationState != AnimationState::none || operation)
      return;

   assert(CDSconnection == nil && "reloadImages:, called while CDS connection is still active");
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
