//
//  EventDisplayViewController.m
//  CERN App
//
//  Created by Eamon Ford on 7/15/12.
//  Copyright (c) 2012 CERN. All rights reserved.
//

//Code with background threads and undefined behavior (shared data
//modification from different threads) was removed and re-written
//by Timur Pocheptsov. Bugs fixed, ugly code removed,
//error handling (at least some) added.

#import <cassert>

#import "EventDisplayViewController.h"
#import "ApplicationErrors.h"
#import "Reachability.h"
//#import "DeviceCheck.h"
#import "GUIHelpers.h"

//We compile as Objective-C++, in C++ const have internal linkage ==
//no need for static or unnamed namespace.
NSString * const sourceDescription = @"Description";
NSString * const sourceBoundaryRects = @"Boundaries";
NSString * const resultImage = @"Image";
NSString * const resultLastUpdate = @"Last Updated";
NSString * const sourceURL = @"URL";

using CernAPP::NetworkStatus;

@implementation EventDisplayViewController {
   unsigned loadingSource;
   NSURLConnection *currentConnection;
   NSMutableData *imageData;
   NSDate *lastUpdated;
   
   Reachability *internetReach;
   MBProgressHUD *noConnectionHUD;
   
   UIButton *refreshButton;
}

//________________________________________________________________________________________
- (void) reachabilityStatusChanged : (Reachability *) current
{
#pragma unused(current)
   
   if (internetReach && [internetReach currentReachabilityStatus] == NetworkStatus::notReachable) {
      if (currentConnection) {
         [currentConnection cancel];
         currentConnection = nil;
         
         loadingSource = 0;
         imageData = nil;
         [self removeSpinners];

         CernAPP::ShowErrorAlert(@"Please, check network!", @"Close");
      }
   }
}

//________________________________________________________________________________________
- (bool) hasConnection
{
   return internetReach && [internetReach currentReachabilityStatus] != NetworkStatus::notReachable;
}

@synthesize sources, downloadedResults, scrollView, pageControl, titleLabel, dateLabel, pageLoaded, needsRefreshButton;

//________________________________________________________________________________________
- (id)initWithCoder : (NSCoder *) aDecoder
{
   if (self = [super initWithCoder : aDecoder]) {
      self.sources = [NSMutableArray array];
      numPages = 0;
      loadingSource = 0;
   }

   return self;
}

//________________________________________________________________________________________
- (void) dealloc
{
   [internetReach stopNotifier];
   [[NSNotificationCenter defaultCenter] removeObserver : self];
}

//________________________________________________________________________________________
- (void) viewDidLoad
{
   [super viewDidLoad];

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

   self.pageControl.numberOfPages = numPages;
   if (numPages == 1)
      [self.pageControl setHidden : YES];
   self.scrollView.backgroundColor = [UIColor blackColor];
   
   pageLoaded = NO;
   
   [[NSNotificationCenter defaultCenter] addObserver : self selector : @selector(reachabilityStatusChanged:) name : CernAPP::reachabilityChangedNotification object : nil];
   internetReach = [Reachability reachabilityForInternetConnection];
   [internetReach startNotifier];
   
   //
   refreshButton = [UIButton buttonWithType : UIButtonTypeCustom];
   refreshButton.backgroundColor = [UIColor clearColor];
   const CGSize &btnSize = CernAPP::navBarBackButtonSize;

   refreshButton.frame = CGRectMake(self.view.frame.size.width - btnSize.width - 5,
                                    (CernAPP::navBarHeight - btnSize.height) / 2.f,
                                    btnSize.width, btnSize.height);
   [refreshButton setImage : [UIImage imageNamed : @"reload.png"] forState : UIControlStateNormal];
   refreshButton.alpha = 0.9f;
   [refreshButton addTarget : self action : @selector(reloadPageFromRefreshControl)
                  forControlEvents : UIControlEventTouchUpInside];
   self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView : refreshButton];
   //
}

//________________________________________________________________________________________
- (void) viewDidAppear : (BOOL) animated
{
   self.scrollView.contentSize = CGSizeMake(self.scrollView.frame.size.width * numPages, 1.f);

   if (![self hasConnection])
      return;

   [self addSpinners];
   [self refresh];
}

//________________________________________________________________________________________
- (void) viewDidUnload
{
    [super viewDidUnload];
    for (UIView *subview in self.scrollView.subviews) {
        if ([subview class] == [UIImageView class]) {
            ((UIImageView *)subview).image = nil;
        }
        [subview removeFromSuperview];
    }
}

//________________________________________________________________________________________
- (void) viewWillDisappear:(BOOL)animated
{
   if (currentConnection)
      [currentConnection cancel];

   [super viewWillDisappear : animated];
}

//________________________________________________________________________________________
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        return YES;
    else
        return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

//________________________________________________________________________________________
- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    currentPage = self.pageControl.currentPage;
}

//________________________________________________________________________________________
- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    CGFloat oldScreenWidth = UIInterfaceOrientationIsPortrait([UIApplication sharedApplication].statusBarOrientation)?[UIScreen mainScreen].bounds.size.height:[UIScreen mainScreen].bounds.size.width;
    
    float scrollViewWidth = self.scrollView.frame.size.width;
    float scrollViewHeight = self.scrollView.frame.size.height;
    self.scrollView.contentSize = CGSizeMake(scrollViewWidth*numPages, 1.0);
    [self.scrollView setContentOffset:CGPointMake(self.scrollView.frame.size.width*currentPage, 0.0)];
    
    [UIView animateWithDuration:duration animations:^{
        for (UIView *subview in self.scrollView.subviews) {
            int page = floor((subview.frame.origin.x - oldScreenWidth / 2) / oldScreenWidth) + 1;
            subview.frame = CGRectMake(scrollViewWidth*page, 0.0, scrollViewWidth, scrollViewHeight);
        }
    }];
}

//________________________________________________________________________________________
- (void) addSourceWithDescription : (NSString *) description URL : (NSURL *) url boundaryRects : (NSArray *) boundaryRects
{
    pageLoaded = NO;
    NSMutableDictionary *source = [NSMutableDictionary dictionary];
    [source setValue : description forKey : sourceDescription];
    [source setValue : url forKey : sourceURL];
    if (boundaryRects) {
        [source setValue : boundaryRects forKey : sourceBoundaryRects];
        // If the image downloaded from this source is going to be divided into multiple images, we will want a separate page for each of these.
        numPages += boundaryRects.count;
    } else {
        numPages += 1;
    }
    [self.sources addObject:source];
}

#pragma mark - Loading event display images

//________________________________________________________________________________________
- (NSUInteger) nOfEventDisplays
{
   NSUInteger nD = 0;

   for (UIView *v in scrollView.subviews)
      if ([v isKindOfClass : [UIImageView class]])
         ++nD;
 
   return nD;
}

//________________________________________________________________________________________
- (UIImageView *) imageViewForTheCurrentPage
{
   const NSInteger page = self.pageControl.currentPage;
   const CGFloat scrollViewWidth = scrollView.frame.size.width;
   const CGFloat innerX = page * scrollViewWidth + 0.5f * scrollViewWidth;
   
   for (UIView *v in scrollView.subviews) {
      if ([v isKindOfClass : [UIImageView class]]) {
         const CGRect viewFrame = v.frame;
         if (innerX > viewFrame.origin.x && innerX < viewFrame.origin.x + viewFrame.size.width)
            return (UIImageView *)v;
      }
   }
   
   return nil;
}

//________________________________________________________________________________________
- (void) showErrorHUD
{
   noConnectionHUD = [MBProgressHUD showHUDAddedTo : self.scrollView animated : NO];
   noConnectionHUD.color = [UIColor redColor];
   noConnectionHUD.delegate = self;
   noConnectionHUD.mode = MBProgressHUDModeText;
   noConnectionHUD.labelText = @"No network";
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
   [MBProgressHUD hideAllHUDsForView : self.scrollView animated : NO];

   if (![self hasConnection]) {
      UIImageView * currentView = [self imageViewForTheCurrentPage];
      if ((currentView && !currentView.image) || ![self nOfEventDisplays])
         [self showErrorHUD];
         //otherwise, just show the old image.
      return;
   }

   if (currentConnection)
      [currentConnection cancel];
   
   pageLoaded = NO;

   // If the event display images from a previous load are already in the scrollview, remove all of them before refreshing.
   for (UIView *subview in self.scrollView.subviews) {
      if ([subview class] == [UIImageView class])
         [subview removeFromSuperview];
   }
   
   if ([sources count]) {
      [self addSpinnerToPage : self.pageControl.currentPage];
      refreshButton.enabled = NO;
      self.downloadedResults = [NSMutableArray array];
      NSDictionary * const source = [sources objectAtIndex : 0];
      NSURL * const url = [source objectForKey : sourceURL];
      NSURLRequest * const request = [NSURLRequest requestWithURL : url];
      loadingSource = 0;
      imageData = [[NSMutableData alloc] init];
      currentConnection = [[NSURLConnection alloc] initWithRequest : request delegate : self startImmediately : YES];
   }
}

//________________________________________________________________________________________
- (IBAction) refresh : (id) sender
{
   //This method is connected to the "reload" button.

   if (![self hasConnection])
      CernAPP::ShowErrorAlert(@"Please, check network!", @"Close");

   [self refresh];
}

//________________________________________________________________________________________
- (void) synchronouslyDownloadImageForSource : (NSDictionary *) source
{
    // Download the image from the specified source
    NSURL *url = [source objectForKey : sourceURL];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] init];
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:nil];
    UIImage *image = [UIImage imageWithData : data];
    
    NSDate *updated = [self lastModifiedDateFromHTTPResponse:response];

    // Just set the date in the nav bar to the date of the first image, because they should all be pretty much the same anyway
    if (self.downloadedResults.count == 0) {
        self.dateLabel.text = [self timeAgoStringFromDate:updated];
    }
    
    // If the downloaded image needs to be divided into several smaller images, do that now and add each
    // smaller image to the results array.
    NSArray *boundaryRects = [source objectForKey:sourceBoundaryRects];
    if (boundaryRects) {
        for (NSDictionary *boundaryInfo in boundaryRects) {
            NSValue *rectValue = [boundaryInfo objectForKey:@"Rect"];
            CGRect boundaryRect = [rectValue CGRectValue];
            CGImageRef imageRef = CGImageCreateWithImageInRect(image.CGImage, boundaryRect);
            UIImage *partialImage = [UIImage imageWithCGImage:imageRef];
            CGImageRelease(imageRef);
            NSDictionary *imageInfo = [NSMutableDictionary dictionary];
            [imageInfo setValue:partialImage forKey:resultImage];
            [imageInfo setValue:[boundaryInfo objectForKey:sourceDescription] forKey:sourceDescription];
            [imageInfo setValue:updated forKey:resultLastUpdate];
            [self.downloadedResults addObject:imageInfo];
            [self addDisplay:imageInfo toPage:self.downloadedResults.count-1];
        }
    } else {    // Otherwise if the image does not need to be divided, just add the image to the results array.
        NSDictionary *imageInfo = [NSMutableDictionary dictionary];
        [imageInfo setValue:image forKey:resultImage];
        [imageInfo setValue:[source objectForKey:sourceDescription] forKey : sourceDescription];
        [imageInfo setValue:updated forKey:resultLastUpdate];
        [self.downloadedResults addObject:imageInfo];
        [self addDisplay:imageInfo toPage:self.downloadedResults.count-1];
    }
    
    if (self.downloadedResults.count == numPages) {
        refreshButton.enabled = YES;
    }
}

//________________________________________________________________________________________
- (NSDate *)lastModifiedDateFromHTTPResponse:(NSHTTPURLResponse *)response
{
    NSDictionary *allHeaderFields = response.allHeaderFields;
    NSString *lastModifiedString = [allHeaderFields objectForKey:@"Last-Modified"];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"EEE',' dd' 'MMM' 'yyyy HH':'mm':'ss zzz"];
    
    return [dateFormatter dateFromString:lastModifiedString];
}

//________________________________________________________________________________________
- (NSString *)timeAgoStringFromDate:(NSDate *)date
{
    int secondsAgo = abs([date timeIntervalSinceNow]);
    NSString *dateString;
    if (secondsAgo<60*60) {
        dateString = [NSString stringWithFormat:@"%d minutes ago", secondsAgo/60];
    } else if (secondsAgo<60*60*24) {
        dateString = [NSString stringWithFormat:@"%0.1f hours ago", (float)secondsAgo/(60*60)];
    } else {
        dateString = [NSString stringWithFormat:@"%0.1f days ago", (float)secondsAgo/(60*60*24)];
    }
    return dateString;
}
        
#pragma mark - UI methods

//________________________________________________________________________________________
- (void)addDisplay:(NSDictionary *)eventDisplayInfo toPage:(int)page
{
   UIImage *image = [eventDisplayInfo objectForKey : resultImage];
   CGRect imageViewFrame = CGRectMake(self.scrollView.frame.size.width*page, 0., self.scrollView.frame.size.width, self.scrollView.frame.size.height);
   UIImageView *imageView = [[UIImageView alloc] initWithFrame:imageViewFrame];
   imageView.contentMode = UIViewContentModeScaleAspectFit;
   imageView.image = image;
   [self.scrollView addSubview:imageView];
}

//________________________________________________________________________________________
- (void) addSpinners
{
   for (int i = 0; i< numPages; i++)
      [self addSpinnerToPage : i];
}

//________________________________________________________________________________________
- (void) addSpinnerToPage : (int) page
{
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    spinner.frame = CGRectMake(self.scrollView.frame.size.width*page, 0.0, self.scrollView.frame.size.width, self.scrollView.frame.size.height);
    [spinner startAnimating];
    [self.scrollView addSubview:spinner];
}

//________________________________________________________________________________________
- (void) removeSpinners
{
   for (UIView * v in self.scrollView.subviews) {
      if ([v isKindOfClass:[UIActivityIndicatorView class]])
         [v removeFromSuperview];
   }
}

//________________________________________________________________________________________
- (void) scrollViewDidScroll : (UIScrollView *)sender
{
   CGFloat pageWidth = self.scrollView.frame.size.width;
   int page = floor((self.scrollView.contentOffset.x - pageWidth / 2) / pageWidth) + 1;
   self.pageControl.currentPage = page;
   
   if (![self hasConnection]) {
      [MBProgressHUD hideAllHUDsForView : self.scrollView animated : NO];
      UIImageView * const v = [self imageViewForTheCurrentPage];
      if ((v && !v.image) || ![self nOfEventDisplays])
         [self showErrorHUD];
   }
}

//________________________________________________________________________________________
- (void) scrollToPage : (NSInteger) page
{
   //When controller is loaded from LiveEventTableView,
   //any image (not at index 0) can be selected in a table,
   //so I have to scroll to this image (page).
   self.scrollView.contentOffset = CGPointMake(page * self.scrollView.frame.size.width, 0);
   self.pageControl.currentPage = page;

   if (![self hasConnection]) {
      [MBProgressHUD hideAllHUDsForView : self.scrollView animated : NO];
      UIImageView *v = [self imageViewForTheCurrentPage];
      if ((v && !v.image) || ![self nOfEventDisplays])
         [self showErrorHUD];
   }
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
   if (!self.downloadedResults.count)
      self.dateLabel.text = [self timeAgoStringFromDate : lastUpdated];

}

//________________________________________________________________________________________
- (void) connectionDidFinishLoading : (NSURLConnection *) urlConnection
{
   assert(loadingSource < [sources count] && "connectionDidFinishLoading, loadingSource is out of bounds");
   
   if ([imageData length]) {
      UIImage * const newImage = [UIImage imageWithData : imageData];
      if (newImage) {
         NSDictionary * const source = (NSDictionary *)[sources objectAtIndex : loadingSource];
         //
         if (!lastUpdated)//TODO: this "lastUpdated" must be replaced with something more reliable.
            lastUpdated = [NSDate date];

         if (NSArray * const boundaryRects = [source objectForKey : sourceBoundaryRects]) {
            for (NSDictionary *boundaryInfo in boundaryRects) {
               NSValue * const rectValue = (NSValue *)[boundaryInfo objectForKey : @"Rect"];
               const CGRect boundaryRect = [rectValue CGRectValue];
               CGImageRef imageRef(CGImageCreateWithImageInRect(newImage.CGImage, boundaryRect));
               UIImage * const partialImage = [UIImage imageWithCGImage : imageRef];
               CGImageRelease(imageRef);
               NSDictionary *imageInfo = [NSMutableDictionary dictionary];
               [imageInfo setValue : partialImage forKey : resultImage];
               [imageInfo setValue : [boundaryInfo objectForKey : sourceDescription] forKey : sourceDescription];
               [imageInfo setValue : lastUpdated forKey : resultLastUpdate];
               [self.downloadedResults addObject : imageInfo];
               [self addDisplay : imageInfo toPage : self.downloadedResults.count - 1];
            }
         } else {
            // Otherwise if the image does not need to be divided, just add the image to the results array.
            NSDictionary * const imageInfo = [NSMutableDictionary dictionary];
            [imageInfo setValue : newImage forKey : resultImage];
            [imageInfo setValue : [source objectForKey : sourceDescription] forKey : sourceDescription];
            [imageInfo setValue : lastUpdated forKey : resultLastUpdate];
            [self.downloadedResults addObject : imageInfo];
            [self addDisplay : imageInfo toPage : self.downloadedResults.count - 1];
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
      refreshButton.enabled = YES;
      [self removeSpinners];
   }
}

//________________________________________________________________________________________
- (void) connection : (NSURLConnection *) urlConnection didFailWithError : (NSError *) error
{
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
      refreshButton.enabled = YES;
   }
}

@end