//
//  EventDisplayViewController.m
//  CERN App
//
//  Created by Eamon Ford on 7/15/12.
//  Copyright (c) 2012 CERN. All rights reserved.
//

//Code with background threads and undefined behavior (shared data
//modification from different threads) was removed and re-written
//by Timur Pocheptsov.

#import <cassert>

#import <Availability.h>

#import "EventDisplayViewController.h"
#import "ECSlidingViewController.h"
#import "MWZoomingScrollView.h"
#import "ApplicationErrors.h"
#import "MWPhotoProtocol.h"
#import "Reachability.h"
#import "DeviceCheck.h"
#import "GUIHelpers.h"
#import "MWPhoto.h"

//We compile as Objective-C++, in C++ const have internal linkage ==
//no need for static or unnamed namespace.
NSString * const sourceDescription = @"Description";
NSString * const sourceBoundaryRects = @"Boundaries";
NSString * const resultImage = @"Image";
NSString * const resultLastUpdate = @"Last Updated";
NSString * const sourceURL = @"URL";

using CernAPP::NetworkStatus;

//
//pageLoaded is a legacy of CERN.app v.1 - I had a multi-page controller there and
//event display view supported PageController protocol.
//

@implementation EventDisplayViewController {
   unsigned loadingPage;
   unsigned loadingSource;

   NSURLConnection *currentConnection;
   NSMutableData *imageData;
   NSDate *lastUpdated;
   
   Reachability *internetReach;
   
   NSMutableArray *pages;

   //Error messages.
   MBProgressHUD *noConnectionHUD;
   
   //UglyUglyUgly
   NSInteger pageBeforeRotation;
}

@synthesize initialPage;

#pragma mark - Reachability and the network status.

//________________________________________________________________________________________
- (void) reachabilityStatusChanged : (Reachability *) current
{
#pragma unused(current)
   
   if (internetReach && [internetReach currentReachabilityStatus] == NetworkStatus::notReachable) {
      if (currentConnection) {
         [currentConnection cancel];
         currentConnection = nil;
         
         //If some page managed to load - ok, but check the remaining.
         for (;loadingPage < pages.count; ++loadingPage) {
            MWZoomingScrollView * const page = (MWZoomingScrollView *)pages[loadingPage];
            [page displayImageFailure];
         }
         
         loadingPage = 0;
         loadingSource = 0;
         imageData = nil;
         
         self.navigationItem.rightBarButtonItem.enabled = YES;

         [self checkCurrentPage];
      }
   }
}

//________________________________________________________________________________________
- (bool) hasConnection
{
   return internetReach && [internetReach currentReachabilityStatus] != NetworkStatus::notReachable;
}

@synthesize sources, scrollView, pageControl, titleLabel, dateLabel, pageLoaded, needsRefreshButton;

#pragma mark - Lifecycle.

//________________________________________________________________________________________
- (id) initWithCoder : (NSCoder *) aDecoder
{
   if (self = [super initWithCoder : aDecoder]) {
      sources = [[NSMutableArray alloc] init];
      pages = [[NSMutableArray alloc] init];

      numPages = 0;
      loadingPage = 0;
      loadingSource = 0;
      
      pageLoaded = NO;
   }

   return self;
}

//________________________________________________________________________________________
- (void) dealloc
{
   if (CernAPP::SystemVersionGreaterThanOrEqualTo(@"7.0"))
      //This is something new or at least Apple never said I need this.
      self.scrollView.delegate = nil;
   
   [self cancelAnyConnections];

   [internetReach stopNotifier];
   [[NSNotificationCenter defaultCenter] removeObserver : self];
}

#pragma mark - UIViewController's overriders.

//________________________________________________________________________________________
- (void) viewDidLoad
{
   [super viewDidLoad];
   
   self.view.backgroundColor = [UIColor blackColor];//WTF it's not taken from the storyboard???

   CGRect titleViewFrame = CGRectMake(0.0, 0.0, 200.0, 44.0);
   UIView *titleView = [[UIView alloc] initWithFrame:titleViewFrame];
   titleView.backgroundColor = [UIColor clearColor];

   titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0, 0.0, titleView.frame.size.width, 24.0)];
   titleLabel.backgroundColor = [UIColor clearColor];
   titleLabel.textColor = [UIColor whiteColor];
   titleLabel.font = [UIFont boldSystemFontOfSize:20.0];
   titleLabel.textAlignment = NSTextAlignmentCenter;
   titleLabel.text = self.title;
   [titleView addSubview : titleLabel];

   dateLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0, titleLabel.frame.size.height, titleView.frame.size.width, titleView.frame.size.height-titleLabel.frame.size.height)];
   dateLabel.backgroundColor = [UIColor clearColor];
   dateLabel.textColor = [UIColor whiteColor];
   dateLabel.font = [UIFont boldSystemFontOfSize:13.0];
   dateLabel.textAlignment = NSTextAlignmentCenter ;

   [titleView addSubview:dateLabel];

   self.navigationItem.titleView = titleView;

   pageControl.numberOfPages = numPages;
   if (numPages == 1)
      [pageControl setHidden : YES];

   scrollView.backgroundColor = [UIColor blackColor];
   
   pageLoaded = NO;
   
   [[NSNotificationCenter defaultCenter] addObserver : self selector : @selector(reachabilityStatusChanged:) name : CernAPP::reachabilityChangedNotification object : nil];
   internetReach = [Reachability reachabilityForInternetConnection];
   [internetReach startNotifier];

   self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem : UIBarButtonSystemItemRefresh target : self action : @selector(reloadPageFromRefreshControl)];
}

//________________________________________________________________________________________
- (void) viewDidAppear : (BOOL) animated
{
   //self.scrollView.contentSize = CGSizeMake(scrollView.frame.size.width * numPages, scrollView.frame.size.height);

   //We do not add anything into the navigation stack, so this method (in principle) is
   //called only once.
   
   if (CernAPP::SystemVersionGreaterThanOrEqualTo(@"7.0") && scrollView) {
#ifdef __IPHONE_7_0
      self.navigationController.interactivePopGestureRecognizer.enabled = NO;
#endif
   }
   
   if (numPages > 1)
      [self.slidingViewController.panGesture requireGestureRecognizerToFail : scrollView.panGestureRecognizer];

   [self refresh];
}

//________________________________________________________________________________________
- (void) viewWillDisappear : (BOOL) animated
{
   if (currentConnection)
      [currentConnection cancel];

   [super viewWillDisappear : animated];
}

//________________________________________________________________________________________
- (void) viewWillAppear : (BOOL) animated
{
   [super viewWillAppear : animated];
}

//________________________________________________________________________________________
- (void) addEventDisplayPage
{
   assert(pages.count < numPages && "addEventDisplayPage, too many pages");
   
   CGRect newFrame = scrollView.frame;
   newFrame.origin.y = 0;
   newFrame.origin.x = pages.count * newFrame.size.width;
   
   MWZoomingScrollView * const newView = [[MWZoomingScrollView alloc] initWithPhotoBrowser : self];
   newView.frame = newFrame;
   [pages addObject : newView];
   newView.imageBroken = NO;
   [newView showSpinner];

   [scrollView addSubview : newView];
   scrollView.contentSize = CGSizeMake(pages.count * newFrame.size.width, newFrame.size.height);
}

//________________________________________________________________________________________
- (void) addEventDisplayPages
{
   assert(pages.count == 0 && "addEventDisplayPages, count is not 0");

   for (NSDictionary *source in sources) {
      if (NSArray * const boundaryRects = source[sourceBoundaryRects]) {
         for (NSDictionary *boundaryInfo in boundaryRects)
            [self addEventDisplayPage];
      } else
         [self addEventDisplayPage];
   }
}

//________________________________________________________________________________________
- (void) addSourceWithDescription : (NSString *) description URL : (NSURL *) url boundaryRects : (NSArray *) boundaryRects
{
   pageLoaded = NO;
   NSMutableDictionary * const source = [NSMutableDictionary dictionary];
   [source setValue : description forKey : sourceDescription];
   [source setValue : url forKey : sourceURL];

   if (boundaryRects) {
      [source setValue : boundaryRects forKey : sourceBoundaryRects];
      // If the image downloaded from this source is going to be divided into multiple images, we will want a separate page for each of these.
      numPages += boundaryRects.count;
   } else {
      numPages += 1;
   }

   [sources addObject : source];
}

#pragma mark - Loading event display images

//________________________________________________________________________________________
- (MWZoomingScrollView *) imageViewForTheCurrentPage
{
   assert(pageControl.currentPage >= 0 && pageControl.currentPage < numPages &&
          "imageViewForTheCurrentPage, current page is out of bounds");
   return (MWZoomingScrollView *)pages[pageControl.currentPage];
}

//________________________________________________________________________________________
- (void) showErrorHUD
{
   [MBProgressHUD hideAllHUDsForView : self.scrollView animated : NO];

   noConnectionHUD = [MBProgressHUD showHUDAddedTo : self.scrollView animated : NO];
   noConnectionHUD.color = [UIColor redColor];
   noConnectionHUD.delegate = self;
   noConnectionHUD.mode = MBProgressHUDModeText;
   noConnectionHUD.labelText = @"Network error";
   noConnectionHUD.removeFromSuperViewOnHide = YES;
}

//________________________________________________________________________________________
- (void) reloadPage
{
   [self refresh];
}

//________________________________________________________________________________________
- (void) reloadPageFromRefreshControl
{
   [self refresh : self];
}

//________________________________________________________________________________________
- (void) refresh
{
   if (![self hasConnection]) {
      if (pages.count) {//we already have pages.
         CernAPP::ShowErrorAlert(@"Please, check network!", @"Close");
         [self checkCurrentPage];
      } else {
         [self showErrorHUD];
         pageControl.hidden = YES;
      }

      return;
   }
   
   if (numPages > 1)
      pageControl.hidden = NO;

   [MBProgressHUD hideAllHUDsForView : self.scrollView animated : NO];

   if (currentConnection)
      [currentConnection cancel];

   // If the event display images from a previous load are already in the scrollview, remove all of them before refreshing.
   [pages removeAllObjects];
   
   for (UIView *subview in self.scrollView.subviews) {
      if ([subview class] == [MWZoomingScrollView class])
         [subview removeFromSuperview];
   }

   pageLoaded = NO;
   loadingPage = 0;
   loadingSource = 0;
   
   if ([sources count]) {
      const NSInteger currentPage = pageControl.currentPage;
      [self addEventDisplayPages];
      pageControl.currentPage = currentPage;

      assert(pageControl.currentPage >= 0 && pageControl.currentPage < pages.count &&
             "refresh, current page is out of bounds");

      if (initialPage) {
         [self scrollToPage : initialPage];
         initialPage = 0;
      } else
         [self scrollToPage : pageControl.currentPage];

      self.navigationItem.rightBarButtonItem.enabled = NO;
      NSDictionary * const source = [sources objectAtIndex : 0];
      NSURL * const url = [source objectForKey : sourceURL];
      NSURLRequest * const request = [NSURLRequest requestWithURL : url];
      imageData = [[NSMutableData alloc] init];
      currentConnection = [[NSURLConnection alloc] initWithRequest : request delegate : self startImmediately : YES];
   }
}

//________________________________________________________________________________________
- (IBAction) refresh : (id) sender
{
   //This method is connected to the "reload" button.
   if (![self hasConnection]) {
      CernAPP::ShowErrorAlert(@"Please, check network!", @"Close");
      return;
   }

   [self refresh];
}

//________________________________________________________________________________________
- (NSDate *) lastModifiedDateFromHTTPResponse : (NSHTTPURLResponse *) response
{
   NSDictionary *allHeaderFields = response.allHeaderFields;
   NSString *lastModifiedString = [allHeaderFields objectForKey : @"Last-Modified"];
   NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
   [dateFormatter setDateFormat : @"EEE',' dd' 'MMM' 'yyyy HH':'mm':'ss zzz"];
    
   return [dateFormatter dateFromString : lastModifiedString];
}

//________________________________________________________________________________________
- (NSString *) timeAgoStringFromDate : (NSDate *) date
{
   const int secondsAgo = abs([date timeIntervalSinceNow]);
   NSString *dateString = nil;

   if (secondsAgo < 60 * 60) {
      dateString = [NSString stringWithFormat : @"%d minutes ago", secondsAgo / 60];
   } else if (secondsAgo < 60 * 60 * 24) {
      dateString = [NSString stringWithFormat : @"%0.1f hours ago", (float)secondsAgo / (60 * 60)];
   } else {
      dateString = [NSString stringWithFormat : @"%0.1f days ago", (float)secondsAgo / (60 * 60 * 24)];
   }

   return dateString;
}
        
#pragma mark - UI methods

//________________________________________________________________________________________
- (void) checkCurrentPage
{
   //Check if we have a network or loading page.
   //If both are no - check if we have an image for the current page.

   if (!pages.count)
      return;

   [MBProgressHUD hideAllHUDsForView : self.scrollView animated : NO];

   assert(pageControl.currentPage >= 0 && pageControl.currentPage < pages.count &&
          "checkCurrentPage, current page is out of bounds");

   MWZoomingScrollView * const page = (MWZoomingScrollView *)pages[pageControl.currentPage];
   if (page.imageBroken)
      [self showErrorHUD];
}

//________________________________________________________________________________________
- (void) scrollViewDidScroll : (UIScrollView *) sender
{
   const CGFloat pageWidth = self.scrollView.frame.size.width;
   const int page = floor((self.scrollView.contentOffset.x - pageWidth / 2) / pageWidth) + 1;
   self.pageControl.currentPage = page;
   
   [self checkCurrentPage];
}

//________________________________________________________________________________________
- (void) scrollToPage : (NSInteger) page
{
   assert(page >= 0 && page < numPages && "scrollToPage:, parameter 'page' is out of bounds");

   //When controller is loaded from LiveEventTableView,
   //any image (not at index 0) can be selected in a table,
   //so I have to scroll to this image (page).
   self.scrollView.contentOffset = CGPointMake(page * self.scrollView.frame.size.width, 0);
   pageControl.currentPage = page;

   [self checkCurrentPage];
}

#pragma mark - NSURLConnectionDelegate

//________________________________________________________________________________________
- (void) connection : (NSURLConnection *) connection didReceiveData : (NSData *)data
{
   assert(imageData != nil && "connection:didReceiveData:, imageData is nil");

   [imageData appendData : data];
}

//________________________________________________________________________________________
- (void) connection : (NSURLConnection *) connection didReceiveResponse : (NSURLResponse *) response
{
   if ([response isKindOfClass : [NSHTTPURLResponse class]])
      lastUpdated = [self lastModifiedDateFromHTTPResponse : (NSHTTPURLResponse *)response];
   else
      lastUpdated = [NSDate date];

   // Just set the date in the nav bar to the date of the first image, because they should all be pretty much the same anyway
   self.dateLabel.text = [self timeAgoStringFromDate : lastUpdated];
}

//________________________________________________________________________________________
- (void) connectionDidFinishLoading : (NSURLConnection *) urlConnection
{
   assert(loadingSource < [sources count] && "connectionDidFinishLoading, loadingSource is out of bounds");
   
   if ([imageData length]) {
      UIImage * const newImage = [UIImage imageWithData : imageData];
      if (newImage) {
         NSDictionary * const source = (NSDictionary *)sources[loadingSource];
         //
         if (!lastUpdated)//TODO: this "lastUpdated" must be replaced with something more reliable.
            lastUpdated = [NSDate date];

         if (NSArray * const boundaryRects = [source objectForKey : sourceBoundaryRects]) {
            for (NSDictionary *boundaryInfo in boundaryRects) {
               assert(loadingPage >= 0 && loadingPage < pages.count &&
                      "connectionDidFinishLoading:, loadingPage is out of bounds");

               NSValue * const rectValue = (NSValue *)[boundaryInfo objectForKey : @"Rect"];
               const CGRect boundaryRect = [rectValue CGRectValue];
               CGImageRef imageRef(CGImageCreateWithImageInRect(newImage.CGImage, boundaryRect));
               UIImage * const partialImage = [UIImage imageWithCGImage : imageRef];
               CGImageRelease(imageRef);

               MWZoomingScrollView * const view = (MWZoomingScrollView *)pages[loadingPage];
               view.photo = [[MWPhoto alloc] initWithImage : partialImage];
               ++loadingPage;
            }
            
            loadingPage += boundaryRects.count;
         } else {
            assert(loadingPage >= 0 && loadingPage < pages.count &&
                   "connectionDidFinishLoading:, loadingPage is out of bounds");
            
            MWZoomingScrollView * const view = (MWZoomingScrollView *)pages[loadingPage];
            view.photo = [[MWPhoto alloc] initWithImage : newImage];
            ++loadingPage;
         }
      }
   }
   
   if (loadingSource + 1 < [sources count]) {
      //We have to continue.
      ++loadingSource;

      NSDictionary * const source = [sources objectAtIndex : loadingSource];
      NSURL * const url = [source objectForKey : sourceURL];
      NSURLRequest * const request = [NSURLRequest requestWithURL : url];
      imageData = [[NSMutableData alloc] init];
      currentConnection = [[NSURLConnection alloc] initWithRequest : request delegate : self startImmediately : YES];
   } else {
      currentConnection = nil;
      imageData = nil;
      loadingSource = 0;
      pageLoaded = YES;
      self.navigationItem.rightBarButtonItem.enabled = YES;
   }
}

//________________________________________________________________________________________
- (void) connection : (NSURLConnection *) urlConnection didFailWithError : (NSError *) error
{
   assert(loadingSource < sources.count && "connection:didFailWithError:, loadingSource is out of bounds");
   assert(loadingPage >= 0 && loadingPage < pages.count && "connection:didFailWithError:, loadingPage is out of bounds");

   NSDictionary * const source = (NSDictionary *)sources[loadingSource];
   if (NSArray * const boundaryRects = (NSArray *)source[sourceBoundaryRects]) {
      for (int pageIndex = loadingPage, e = (int)(loadingPage + boundaryRects.count); pageIndex < e; ++pageIndex) {
         MWZoomingScrollView * const page = (MWZoomingScrollView *)pages[pageIndex];
         [page displayImageFailure];//this will stop spinner and set imageBroken == YES.
      }
      
      loadingPage += boundaryRects.count;//skip broken pages.
   } else {
      MWZoomingScrollView * const page = (MWZoomingScrollView *)pages[loadingPage];
      [page displayImageFailure];//this will stop spinner and set imageBroken == YES.
      ++loadingPage;//we skip the broken page.
   }
   
   if (loadingSource + 1 < [sources count]) {
      ++loadingSource;
      NSDictionary * const source = [sources objectAtIndex : loadingSource];
      NSURL * const url = [source objectForKey : sourceURL];
      NSURLRequest * const request = [NSURLRequest requestWithURL : url];
      imageData = [[NSMutableData alloc] init];
      currentConnection = [[NSURLConnection alloc] initWithRequest : request delegate : self startImmediately : YES];
   } else {
      currentConnection = nil;
      imageData = nil;
      loadingSource = 0;
      pageLoaded = YES;
      self.navigationItem.rightBarButtonItem.enabled = YES;
   }
   
   [self checkCurrentPage];//This will probably set an error HUD.
}

#pragma mark - Sliding view controller.
//________________________________________________________________________________________
- (void) revealMenu : (id) sender
{
#pragma unused(sender)
   [self.slidingViewController anchorTopViewTo : ECRight];
}

#pragma mark - Interface rotation.

//________________________________________________________________________________________
- (BOOL) shouldAutorotate
{
   return pageLoaded;
}

//________________________________________________________________________________________
- (NSUInteger) supportedInterfaceOrientations
{
   return  UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskLandscapeLeft | UIInterfaceOrientationMaskLandscapeRight;
}

//________________________________________________________________________________________
- (void) willRotateToInterfaceOrientation : (UIInterfaceOrientation) toInterfaceOrientation duration : (NSTimeInterval) duration
{
#pragma unused(duration)
   pageBeforeRotation = pageControl.currentPage;//Ufff, uglyugly!!!
   
   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {//We do not hide a title bar on iPad.
      if (UIInterfaceOrientationIsLandscape(toInterfaceOrientation)) {
         [self.navigationController.view removeGestureRecognizer : self.slidingViewController.panGesture];
         [self.navigationController setNavigationBarHidden : YES];
      } else {
         [self.navigationController.view addGestureRecognizer : self.slidingViewController.panGesture];
         [self.navigationController setNavigationBarHidden : NO];
      }
   }
}

//________________________________________________________________________________________
- (void) willAnimateRotationToInterfaceOrientation : (UIInterfaceOrientation) toInterfaceOrientation duration : (NSTimeInterval) duration
{
   if (CernAPP::SystemVersionLessThan(@"7.0")) {
      CGRect pcFrame = pageControl.frame;
      pcFrame.origin.x = self.view.frame.size.width / 2 - pcFrame.size.width / 2;
      pageControl.frame = pcFrame;
   }

   if (pages.count) {
      const CGFloat scrollViewWidth = self.scrollView.frame.size.width;
      const CGFloat scrollViewHeight = self.scrollView.frame.size.height;

      scrollView.contentSize = CGSizeMake(scrollViewWidth * numPages, scrollViewHeight);
      [scrollView setContentOffset : CGPointMake(self.scrollView.frame.size.width * pageControl.currentPage, 0.f)];

      [UIView animateWithDuration : duration animations : ^ {
         for (NSUInteger i = 0, e = pages.count; i < e; ++i) {
            const CGRect pageFrame = CGRectMake(i * scrollViewWidth, 0.f, scrollViewWidth, scrollViewHeight);
            MWZoomingScrollView * const page = (MWZoomingScrollView *)pages[i];
            page.frame = pageFrame;
         }
         
         [self scrollToPage : pageBeforeRotation];
      }];
   }
}

//________________________________________________________________________________________
- (void) didRotateFromInterfaceOrientation : (UIInterfaceOrientation) fromInterfaceOrientation
{
   [self checkCurrentPage];
}

#pragma mark - PhotoBrowserDelegate.

//________________________________________________________________________________________
- (UIImage *) imageForPhoto : (id<MWPhoto>) photo
{
   assert(photo != nil && "imageForPhoto:, parameter 'photo' is nil");
   return [photo underlyingImage];
}

//________________________________________________________________________________________
- (void) cancelControlHiding
{
   //Noop.
}

//________________________________________________________________________________________
- (void) hideControlsAfterDelay
{
   //Noop.
}

//________________________________________________________________________________________
- (void) toggleControls
{
   //Noop.
}

#pragma mark - ConnectionController.

//________________________________________________________________________________________
- (void) cancelAnyConnections
{
   if (currentConnection)
      [currentConnection cancel];
   
   currentConnection = nil;
}

@end
