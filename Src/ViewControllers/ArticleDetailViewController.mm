//
//  ArticleDetailViewController.m
//  CERN App
//
//  Created by Eamon Ford on 6/18/12.
//  Copyright (c) 2012 CERN. All rights reserved.
//

//Modified by Timur Pocheptsov.


//TODO: the description below is obsolete, since we're moving the Readability parse
//from the application to our server.


//
//ArticleDefailtViewController can show either original page,
//or both readability-processed version and original page.
//
//Controller has two web-views (rdbView and pageView) and
//can switch (with flip-animation) between them.
//In addition, we have several button in a navigation bar,
//depending on the current view and state.
//
//When controller's view is loaded (actually, viewDidAppear):
//
//1. (loadHtmlFromReadability) We check rdbCache, if it's not empty, we switch to rdbView,
//   start a spinner and try to load this cached html
//   into the rdbView. Stage is set to LoadStage::rdbCacheLoad, rdbLoaded == NO.
//1.a webViewDidFinishLoad is called, we stop a spinner, stage is set to LoadStage::inactive,
//    rdbLoad == YES, now we enable buttons: "Send", "View original page", "Zoom in", "Zoom out".
//    After this point we ignore any messages from webView (didFinish can be called many times, unfortunately).
//1.b webViewDidFailWithError is called, we stop webView loading, assume that readability does
//    not work, set the rdbCache to nil, and now we're trying to load original page into a pageView.
//
//loadOriginalPage: checks a network connection, if it's active - stage = LoadStage::originalPageLoad,
//                  and we start page loading. if there is no connection, we show error HUD message and
//                  enable buttons:
//                    1. if rdbLoaded == YES - "Switch to readability view" and "Refresh" buttons.
//                    2. else - "Refresh" button.
//                  if there is a connection, we try to load original page (now delegate methods):
//                  -webViewDidFinishLoad:, stage = LoadStage::inactive, stop the spinner, pageLoaded = YES,
//                  enable buttons:
//                    1. if rdbLoaded == YES: "Switch to readability view" and "Send" buttons.
//                    2. else "Send" button.
//
//2. (loadHtmlFromReadability) We check rdbCase, it's nil. Start a spinner, switch to readability view,
//   and
//2.a (readabilityParseHtml) if we have OAuth tokens for readability already, we're now trying to send a request to
//    content parser (from this point, urlConnection delegate's methods work).
//     - didReceiveRespond: 200 - ok, we continue to work
//          -didReceiveData: we append data.
//          -didFinishLoad: we're trying to read readability's respond,
//                         a. success: we assign rdbCache and try to load readability cache - goto 1.
//                         b. failure: we're trying to load original page now and do not use redability for this article.
//          -didFailWithError: cancel the current connection and try to load original page.
//
//     - didReceiveRespond: 401 - something is wrong with tokens: cancel current connection:
//                          a. if we did not try to do auth here (were using old tokens?) - try readability auth
//                          b. switch to page view and load original page.
//     - didReceiveRespond: something else, still error: cancel current connection,
//                          switch to pageView and try to load original page.
//2.b (readabilityAuth) First, try to obtain security tokens for readability. We send a reques, now urlConnection delegate's methods are called:
//     - didReceiveRespond: 200 - ok.
//     - didReceiveRespond: something else: cancel the current connection, switch to the page view, load original page, readability is
//       is not used anymore for this article.
//     - didReceiveData: append the data
//     - didFinishLoad: try to extract security tokens:
//       a. success - now try to send request to the readability's parser.
//       b. failure - do not try to use readability anymore, try to load original page.
//     - didFailWithError: cancel the current connection, do not try to use readability
//                         for this page anymore, switch to the page view, load original page.
//
//
//Stage LoadStage::needRefresh means some error while loading,
// can be both with rdbCase available, and without.
//      - we have rdbCache, refresh is required only for original page view.
//      - no cache, readability view is no avaiable, we can refresh original page view.
//
//If readability failed:
//    - error while sending auth request
//    - respond != 200
//    - auth connection failed
//    - can not extract security tokens
//    - error while sending request to the parser
//    - respond from parser != 200 (if it's 401 and we did not try auth, try it now).
//    - parser connection failed
//    - can not extract parsed article
//    - can not load readability-processed article (rdbCache)
//we do not try to use readability anymore and try to load original page.
//
//Controller receives notification about network status changes.
//If stage == LoadStage::invactive, these notifications are discarded.
//Otherwise, we cancel any connection/web view load operations,
//and set the stage to the LoadStage::lostNetworkConnection, set the hood
//and set the buttons (depend on data already loaded).
//


#import <Social/Social.h>
#import <Availability.h>

#import "ArticleDetailViewController.h"
#import "ECSlidingViewController.h"
#import "ApplicationErrors.h"
#import "PictureButtonView.h"
#import "MBProgressHUD.h"
#import "NSString+HTML.h"
#import "Reachability.h"
#import "DeviceCheck.h"
#import "AppDelegate.h"
#import "GUIHelpers.h"
#import "APNUtils.h"
#import "GCOAuth.h"

namespace {

enum class LoadStage : unsigned char {
   inactive,
   lostNetworkConnection,
   auth,
   linkRequest,
   rdbRequest,
   rdbCacheLoad,
   originalPageLoad
};

//________________________________________________________________________________________
CGFloat DefaultHTMLBodyFontSize()
{
   //Some number in a range [0, 20]

   NSUserDefaults * const defaults = [NSUserDefaults standardUserDefaults];
   if (id sz = [defaults objectForKey : CernAPP::htmlBodyFontSizeKey]) {
      assert([sz isKindOfClass : [NSNumber class]] && "DefaultHTMLBodyFontSize, dictionary expected");
      return [(NSNumber *)sz floatValue];
   }
   
   return 0.f;
}

const NSUInteger fontIncreaseStep = 4;

}



@implementation ArticleDetailViewController {
   NSString *articleLink;
   NSString *sha1Link;
   BOOL apnLoaded;
   
   UIActivityIndicatorView *spinner;
   
   Reachability *internetReach;

   LoadStage stage;
   NSInteger status;
   NSMutableData *responseData;
   NSURLConnection *currentConnection;
   BOOL authDone;
   BOOL pageLoaded;
   
   UIButton *zoomInBtn;
   UIButton *zoomOutBtn;
   NSUInteger zoomLevel;

   OverlayView *sendOverlay;
   BOOL animatingOverlay;
   
   MBProgressHUD *noConnectionHUD;
   
   //I need this for Readability + CoreData.
   NSString *responseEncoding;
   //
   NSTimer *timeoutGuard;
   
   BOOL isInTransition;
}

@synthesize rdbView, pageView, containerView, rdbCache, articleID, title, canUseReadability;

//It has to be included here, since the file contains
//methods.
#import "Readability.h"

//________________________________________________________________________________________
+ (NSString *) cssFileName
{
   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
      return @"ArticleiPadCSS";
   
   return @"ArticleCSS";
}

//________________________________________________________________________________________
- (BOOL) isInActiveStage
{
   return stage != LoadStage::inactive && stage != LoadStage::lostNetworkConnection;
}

#pragma mark - Notifications (from the Reachability and NSUserDefaults).

//________________________________________________________________________________________
- (void) reachabilityStatusChanged : (Reachability *) current
{
#pragma unused(current)
   using CernAPP::NetworkStatus;
   
   if (internetReach && [internetReach currentReachabilityStatus] == NetworkStatus::notReachable) {
      [rdbView stopLoading];
      [pageView stopLoading];

      if (currentConnection) {
         [currentConnection cancel];
         currentConnection = nil;
      }

      [self stopSpinner];
      [self stopTimer];

      if ([self isInActiveStage]) {
         //We show the message and change buttons
         //ONLY if view was loading at the time of this
         //reachability status change.

         [self showErrorHUD];

         stage = LoadStage::lostNetworkConnection;
         [self addWebBrowserButtons];
      }
   }
}

//________________________________________________________________________________________
- (void) defaultsChanged : (NSNotification *) notification
{
   //Defaults for the article are the font size in a readability view.
   if ([notification.object isKindOfClass : [NSUserDefaults class]]) {
      NSUserDefaults * const defaults = (NSUserDefaults *)notification.object;
      if (id sz = [defaults objectForKey : CernAPP::htmlBodyFontSizeKey]) {
         assert([sz isKindOfClass : [NSNumber class]] && "defaultsChanged:, HTMLBodyFontSize has a wrong type");

         const NSUInteger newZoom = NSUInteger([(NSNumber *)sz floatValue]) / fontIncreaseStep;
         if (newZoom != zoomLevel) {
            zoomLevel = newZoom;
            
            if (rdbView.superview) {//Is the Readability view active now?
               [self changeTextSize];
               zoomInBtn.enabled = zoomLevel < 5 ? YES : NO;
               zoomOutBtn.enabled = zoomLevel != 0 ? YES : NO;
            }
         }       
      }
   }
}

#pragma mark - Life cycle.

//________________________________________________________________________________________
- (id) initWithNibName : (NSString *) nibNameOrNil bundle : (NSBundle *) nibBundleOrNil
{
   if (self = [super initWithNibName : nibNameOrNil bundle : nibBundleOrNil]) {
      apnLoaded = NO;
      
      status = 200;
      stage = LoadStage::inactive;
      pageLoaded = NO;
      authDone = NO;
      
      timeoutGuard = nil;
      
      isInTransition = NO;
   }

   return self;
}

//________________________________________________________________________________________
- (void) dealloc
{
   [self cancelAnyConnections];
   [internetReach stopNotifier];
   [[NSNotificationCenter defaultCenter] removeObserver : self];
}

//________________________________________________________________________________________
- (void) viewWillAppear : (BOOL)animated
{
   [super viewWillAppear : animated];
   
   if (CernAPP::SystemVersionGreaterThanOrEqualTo(@"7.0")) {
      UIEdgeInsets insets = {};
      insets.top = self.navigationController.navigationBar.frame.size.height + 20.f;
      rdbView.scrollView.contentInset = insets;
      pageView.scrollView.contentInset = insets;
   }
}

//________________________________________________________________________________________
- (void) viewDidAppear : (BOOL) animated
{
   //Called only once (?)
   [super viewDidAppear : animated];
   
   if (CernAPP::SystemVersionGreaterThanOrEqualTo(@"7.0")) {
#ifdef __IPHONE_7_0
      self.navigationController.interactivePopGestureRecognizer.enabled = NO;
#endif
   }

   //1. Setup views.
   CGRect frame = self.view.frame;
   frame.origin = CGPoint();
   
   const CGFloat presetSize = DefaultHTMLBodyFontSize();
   assert(presetSize >= 0.f && presetSize <= 20.f && "viewDidAppear, unexpected text size from app settings");
   zoomLevel = unsigned(presetSize) / fontIncreaseStep;

   rdbView.frame = frame;
   pageView.frame = frame;
   
   rdbView.multipleTouchEnabled = YES;
   pageView.multipleTouchEnabled = YES;
   
   //2. Load something: cached html/article link/readability's html/original page.
   pageLoaded = NO;
   authDone = NO;

   status = 200;
   stage = LoadStage::inactive;

   [self addSpinner];

   if (canUseReadability && articleID && [ArticleDetailViewController articleCached : articleID] && !sha1Link)
      [self getReadabilityCache];

   [self startSpinner];

   if (sha1Link) {
      [self switchToRdbView];
      [self loadArticleLink];
   } else if (rdbCache && rdbCache.length) {
      [self switchToRdbView];
      [self loadReadabilityCache];
   } else {
#ifndef READABILITY_CONTENT_API_DEFINED
      [self switchToPageView];
      [self loadOriginalPage];
#else
      if (canUseReadability) {
         [self switchToRdbView];
         [self loadHtmlFromReadability];
      } else {
         [self switchToPageView];
         [self loadOriginalPage];
      }
#endif
   }
}

//________________________________________________________________________________________
- (void) viewDidLoad
{
   [[NSNotificationCenter defaultCenter] addObserver : self selector : @selector(reachabilityStatusChanged:) name : CernAPP::reachabilityChangedNotification object : nil];
   internetReach = [Reachability reachabilityForInternetConnection];
   [internetReach startNotifier];
   
   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
      //TODO: find a right way - on iPad with have an auto layout enabled. And still these
      //views are not resized correctly. On iPhone where is no autolayout, and ... they are
      //resized correctly. Bullshit.
      rdbView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
                                 UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
                                 UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
      pageView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
                                  UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
                                  UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
   }
   
   rdbView.scrollView.delegate = self;
   
   [[NSNotificationCenter defaultCenter] addObserver : self selector : @selector(defaultsChanged:) name : NSUserDefaultsDidChangeNotification object : nil];
}

//________________________________________________________________________________________
- (void) setContentForArticle : (MWFeedItem *) article
{
   assert(article != nil && "setContentForArticle:, parameter 'article' is nil");
   assert(article.link != nil && "setContentForArticle:, article link is nil");

   articleLink = article.link;
   title = article.title;
   //thumbnail = article.image;
}

//________________________________________________________________________________________
- (void) setLink : (NSString *) link title : (NSString *) aTitle
{
   assert(link != nil && "setLink:title:, parameter 'link' is nil");
   assert(aTitle != nil && "setLink:title:, parameter 'title' is nil");
   
   articleLink = link;
   title = aTitle;
}

//________________________________________________________________________________________
- (void) setSha1Link : (NSString *) link
{
   assert(link != nil && "setSha1Link:, parameter 'link' is nil");
   
   sha1Link = link;
   articleID = nil;//link;
   title = @"";
   apnLoaded = YES;
}

#pragma mark - UIWebViewDelegate protocol.

//________________________________________________________________________________________
- (BOOL) webView : (UIWebView *) webView shouldStartLoadWithRequest : (NSURLRequest *)request navigationType : (UIWebViewNavigationType) navigationType
{
   if (navigationType == UIWebViewNavigationTypeLinkClicked) {
      [[UIApplication sharedApplication] openURL : [request URL]];
      return NO;
   }

   return YES;
}

//________________________________________________________________________________________
- (void) webView : (UIWebView *) webView didFailLoadWithError : (NSError *) error
{
#pragma unused(error)

   [self stopTimer];
   [webView stopLoading];
   
   if (stage == LoadStage::originalPageLoad && webView == pageView) {
      [self stopSpinner];
      [self showErrorHUD];
      stage = LoadStage::lostNetworkConnection;
      [self addWebBrowserButtons];
   } else if (stage == LoadStage::rdbCacheLoad && webView == rdbView) {
      //Due to some reason, we can not load html processed by readability.
      //I can not assume anything about it - may be, some part (e.g. referenced image)
      //not found, may be something else, since webViewDidFinishLoad was not called before,
      //I simply dispose this cache and do not try readability on this link anymore.
      
      rdbCache = nil;//Do not use it anymore.

      [self switchToPageView];
      [self loadOriginalPage];
   }
}

//________________________________________________________________________________________
- (void) webViewDidFinishLoad : (UIWebView *) webView
{
#pragma unused(webView)

   [self stopTimer];
   [self stopSpinner];

   if (stage == LoadStage::originalPageLoad && webView == pageView) {
      pageLoaded = YES;
      stage = LoadStage::inactive;
      [self addWebBrowserButtons];
   } else if (stage == LoadStage::rdbCacheLoad && webView == rdbView) {
      stage = LoadStage::inactive;
      [self addWebBrowserButtons];
      [self changeTextSize];
   } else {
      [webView stopLoading];//vroom-vroom.
   }
}

#pragma mark - Readability and web-view.

//________________________________________________________________________________________
- (void) loadHtmlFromReadability
{
   assert(currentConnection == nil && "loadHtmlFromReadability, connection is active");
   
   //We do not have a cached html from Readability yet,
   //try to either auth and parse, or pars (if auth was done already).

   //TODO: why do I have this method at all and
   [self readabilityParseHtml];
}

//________________________________________________________________________________________
- (void) loadArticleLink
{
   assert(currentConnection == nil && "loadArticleLink, has an active connection");

   using CernAPP::NetworkStatus;
   
   if (internetReach && [internetReach currentReachabilityStatus] != NetworkStatus::notReachable) {
      assert(sha1Link != nil && "loadArticleLink, sha1Link is invalid");
    
      NSString * const urlString =[NSString stringWithFormat : @"http://cernapp.cern.ch/%@.lnk", sha1Link];
      if (NSURL * const url = [NSURL URLWithString : urlString]) {
         if (NSURLRequest * const urlRequest = [NSURLRequest requestWithURL : url]) {
            stage = LoadStage::linkRequest;
            currentConnection = [NSURLConnection connectionWithRequest : urlRequest delegate : self];
            return;
         }
      }
   }

   [self stopOnLinkLoadError];
}

//________________________________________________________________________________________
- (void) loadReadabilityCache
{
   assert(rdbCache != nil && rdbCache.length && "loadReadabilityCache, no cache");
   
   stage = LoadStage::rdbCacheLoad;
   
   NSString * const cssPath = [[NSBundle mainBundle] pathForResource : [self.class cssFileName] ofType:@"css"];
   NSMutableString *htmlString = [NSMutableString stringWithFormat :
                                                @"<html><head><link rel='stylesheet' type='text/css' "
                                                "href='file://%@'></head><body></p></body></html><h1>%@</h1>%@<p class='read'>",
                                                cssPath, title, rdbCache];

   [self stopTimer];
   [self startTimer];
   [rdbView loadHTMLString : htmlString baseURL : nil];
}

//________________________________________________________________________________________
- (void) loadOriginalPage
{
   assert(currentConnection == nil && "loadOriginalPage, has an active connection");

   using CernAPP::NetworkStatus;

   if (internetReach && [internetReach currentReachabilityStatus] == NetworkStatus::notReachable) {
      [self stopSpinner];
      
      stage = LoadStage::lostNetworkConnection;

      [self showErrorHUD];
      [self addWebBrowserButtons];
   } else {
      //Load original page.
      assert(articleLink != nil && "loadOriginalPage, articleLink is nil");

      stage = LoadStage::originalPageLoad;

      NSURL * const url = [NSURL URLWithString : articleLink];
      NSURLRequest * const request = [NSURLRequest requestWithURL : url];
      pageLoaded = NO;
      
      [self stopTimer];
      [self startTimer];
      [pageView loadRequest : request];
   }
}

//________________________________________________________________________________________
- (BOOL) extractAuthTokens
{
   assert(stage == LoadStage::auth && "extractAuthTokens, wrong stage");
   assert(responseData != nil && "extractAuthTokens, response data is nil");
   
   //Delegate.
   id delegateBase = [UIApplication sharedApplication].delegate;
   assert([delegateBase isKindOfClass : [AppDelegate class]] &&
          "extractAuthTokens, app delegate has a wrong type");
   AppDelegate * const appDelegate = (AppDelegate *)delegateBase;
   appDelegate.OAuthToken = nil, appDelegate.OAuthTokenSecret = nil;
   
   //Parse the responce.
   NSString *OAuthToken = nil;
   NSString *OAuthTokenSecret = nil;
   NSString *OAuthConfirm = nil;

   NSString * const response = [[NSString alloc] initWithData : responseData encoding : NSUTF8StringEncoding];

   NSArray * const components = [response componentsSeparatedByString : @"&"];
   for (NSString *component in components) {
      NSArray *pair = [component componentsSeparatedByString:@"="];
      if (pair.count != 2) {
         //Before I had an assert here and was assuming, this can
         //never happen, but it can :) I still did not check what
         //is the response in such a case (happens 1-2 times a day) :)
         OAuthConfirm = nil;
         OAuthToken = nil;
         OAuthTokenSecret = nil;
         break;
      }

      if ([(NSString *)pair[0] isEqualToString : @"oauth_token_secret"])
         OAuthTokenSecret = (NSString *)pair[1];
      else if ([(NSString *)pair[0] isEqualToString : @"oauth_token"])
         OAuthToken = (NSString *)pair[1];
      else if ([(NSString *)pair[0] isEqualToString : @"oauth_callback_confirmed"])
         OAuthConfirm = (NSString *)pair[1];
   }
   
   if (OAuthToken && OAuthTokenSecret && OAuthConfirm && [OAuthConfirm isEqualToString : @"true"]) {
      appDelegate.OAuthToken = OAuthToken;
      appDelegate.OAuthTokenSecret = OAuthTokenSecret;
      
      return YES;
   }
   
   return NO;
}

#pragma mark - NSURLConnectionDelegate and NSURLConnectionDataDelegate.

//________________________________________________________________________________________
- (void) connection : (NSURLConnection *) connection didReceiveResponse : (NSURLResponse *) response
{
#pragma unused(connection)

   assert((stage == LoadStage::auth || stage == LoadStage::rdbRequest || stage == LoadStage::linkRequest) &&
          "connection:didReceiveResponse:, wrong stage");
   assert(response != nil && "connection:didReceiveResponse:, parameter 'response' is nil");

   if ([response isKindOfClass : [NSHTTPURLResponse class]])
      status = [(NSHTTPURLResponse *)response statusCode];
   else
      status = 200;//???

   if (!responseData)
      responseData = [[NSMutableData alloc] init];
   [responseData setLength : 0];
   
   if (status != 200) {
      [currentConnection cancel];
      currentConnection = nil;
      
      if (stage == LoadStage::linkRequest) {
         [self stopOnLinkLoadError];
      } else if (stage == LoadStage::auth) {
         //Load original page, we can not try authorization again
         //(it can fail again and again).
         [self switchToPageView];
         [self loadOriginalPage];
      } else if (status == 401 && !authDone) {
         //We did not try to do auth yet.
         //Looks like our auth tokens expired.
         [self switchToRdbView];//select rdb view, if not yet.
         [self readabilityAuth];
      } else {
         [self switchToPageView];
         [self loadOriginalPage];
      }
   } else if (stage == LoadStage::rdbRequest) {
      //I'm not quite sure if I should do this at all.
      responseEncoding = [response textEncodingName];
   }
}

//________________________________________________________________________________________
- (void) connection : (NSURLConnection *) connection didReceiveData : (NSData *) data
{
#pragma unused(connection)
   assert((stage == LoadStage::auth || stage == LoadStage::rdbRequest || stage == LoadStage::linkRequest) &&
          "connection:didReceiveData:, wrong stage");
   assert(responseData != nil && "connection:didReceiveData:, 'responseData' is nil");
   
   [responseData appendData : data];
}

//________________________________________________________________________________________
- (void) connectionDidFinishLoading : (NSURLConnection *) connection
{
   assert((stage == LoadStage::auth || stage == LoadStage::rdbRequest || stage == LoadStage::linkRequest) &&
          "connectionDidFinishLoading:, wrong stage");

   using CernAPP::NetworkStatus;

   currentConnection = nil;

   if (stage == LoadStage::linkRequest) {
      if (responseData.length) {
         NSError * err = nil;
         NSDictionary * const json = [NSJSONSerialization JSONObjectWithData : responseData options : NSJSONReadingAllowFragments error : &err];
         if (json) {
            if (json[CernAPP::apnTitleKey]) {
               assert([json[CernAPP::apnTitleKey] isKindOfClass : [NSString class]] &&
                      "connectionDidFinishLoading:, title has a wrong type");
               title = (NSString *)json[CernAPP::apnTitleKey];
            }

            if (json[CernAPP::apnUrlKey]) {
               assert([json[CernAPP::apnUrlKey] isKindOfClass : [NSString class]] &&
                      "connectionDidFinishLoading:, article link has a wrong type");
               sha1Link = nil;
               articleLink = json[CernAPP::apnUrlKey];
               return [self loadHtmlFromReadability];
            }
         }
      }

      //If no url found:
      [self stopOnLinkLoadError];
   } else if (stage == LoadStage::auth) {
      //Ok, we, probably, received tokens, try to extract them.
      if ([self extractAuthTokens])
         [self readabilityParseHtml];
      else {
         [self switchToPageView];
         [self loadOriginalPage];
      }
   } else {
      //We, probably, have content parsed from Readability.
      if (![self extractReadabilityContent]) {
         [self switchToPageView];
         [self loadOriginalPage];
      }
   }
}

//________________________________________________________________________________________
- (void) connection : (NSURLConnection *) connection didFailWithError : (NSError *) error
{
#pragma unused(connection)

   assert(stage == LoadStage::auth || stage == LoadStage::rdbRequest &&
          "connection:didFailWithError:, wrong stage");
   
   currentConnection = nil;

   if (sha1Link) {
      [self stopOnLinkLoadError];
   } else {
      //Something is wrong with readability, either auth. failed
      //or readability parse stage, do not try anything else,
      //load the original page.
      [self switchToPageView];
      [self loadOriginalPage];
   }
}

#pragma mark - "Browser"
//________________________________________________________________________________________
- (void) changeTextSize
{
   const int add = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone ? 44 : 20;

   const int fontSize = add + (int)(fontIncreaseStep * zoomLevel);
   NSString * const jsString = [[NSString alloc] initWithFormat : @"document.getElementsByTagName('body')[0].style.fontSize=%d", fontSize];
   [rdbView stringByEvaluatingJavaScriptFromString : jsString];
}

//________________________________________________________________________________________
- (void) flipWebViews
{
   if (isInTransition)
      return;

   const UIViewAnimationOptions transitionOptions = UIViewAnimationOptionTransitionFlipFromLeft;

   isInTransition = YES;

   if (rdbView.superview) {
      //Switch to original web-page.
      [rdbView stopLoading];//?
      [UIView transitionFromView : rdbView toView : pageView duration : 1.f options : transitionOptions completion : ^(BOOL finished) {
         if (finished) {
            isInTransition = NO;
            stage = LoadStage::inactive;
            if (!pageLoaded) {
               [self startSpinner];
               [self hideWebBrowserButtons];
               [self loadOriginalPage];
            } else
               [self addWebBrowserButtons];
         }
      }];

   } else {
      [pageView stopLoading];
      //
      [MBProgressHUD hideAllHUDsForView : self.view animated : NO];
      //
      [UIView transitionFromView : pageView toView : rdbView duration : 1.f options : transitionOptions completion : ^(BOOL finished) {
         if (finished) {
            isInTransition = NO;
            stage = LoadStage::inactive;
            [self addWebBrowserButtons];
         }
      }];      
   }
}

//________________________________________________________________________________________
- (void) zoomIn
{
   if (isInTransition)
      return;

   if (zoomLevel + 1 == 5)
      zoomInBtn.enabled = NO;

   zoomOutBtn.enabled = YES;

   ++zoomLevel;
   
   [[NSUserDefaults standardUserDefaults] setFloat : CGFloat(zoomLevel * fontIncreaseStep) forKey : CernAPP::htmlBodyFontSizeKey];
   [[NSUserDefaults standardUserDefaults] synchronize];

   [self changeTextSize];   
}

//________________________________________________________________________________________
- (void) zoomOut
{
   if (isInTransition)
      return;

   if (zoomLevel - 1 == 0)
      zoomOutBtn.enabled = NO;

   zoomInBtn.enabled = YES;
   
   --zoomLevel;
   
   [[NSUserDefaults standardUserDefaults] setFloat : zoomLevel * fontIncreaseStep forKey : CernAPP::htmlBodyFontSizeKey];
   [[NSUserDefaults standardUserDefaults] synchronize];
   
   [self changeTextSize];
}

//________________________________________________________________________________________
- (void) sendArticle
{
   if (animatingOverlay || isInTransition)
      return;

   //Woo-hoo.
   CGRect frame = self.view.frame;
   frame.origin.x = 0.f;
   frame.size.height += 66;
   frame.origin.y = -frame.size.height;

   sendOverlay = [[OverlayView alloc] initWithFrame : frame];
   sendOverlay.delegate = self;
   
   [self addSendButtons];

   [self.navigationController.view addSubview : sendOverlay];
   
   frame.origin.y = 0.f;
   
   [UIView animateWithDuration : 0.25f animations : ^ {
      sendOverlay.frame = frame;
   } completion : nil];
}

//________________________________________________________________________________________
- (void) composeEmail
{
   if (![MFMailComposeViewController canSendMail]) {
      UIAlertView *alert = [[UIAlertView alloc] initWithTitle : @"Send e-mail:"
                                                message : @"Please, add your e-mail account in the device settings"
                                                delegate : nil
                                                cancelButtonTitle : @"Close"
                                                otherButtonTitles : nil];
      [alert show];
      return;
   }

   MFMailComposeViewController * mailComposer = [[MFMailComposeViewController alloc] init];
   [mailComposer setSubject:@"E-mail from CERN.app"];
   [mailComposer setMessageBody : articleLink isHTML : NO];
   mailComposer.mailComposeDelegate = self;

   [self presentViewController : mailComposer animated : YES completion : nil];
}

//________________________________________________________________________________________
- (void) sendEmail
{
   void (^mailSenderBlock) (BOOL) = ^ (BOOL finished) {
      if (finished) {
         [sendOverlay removeFromSuperview];
         sendOverlay = nil;
         animatingOverlay = NO;
         [self composeEmail];
      }
   };
   
   [self dismissOverlayView : mailSenderBlock];
}

//________________________________________________________________________________________
- (void) refresh
{
   if (isInTransition)
      return;

   assert(stage == LoadStage::lostNetworkConnection && "refresh, wrong stage");
   assert((rdbView.superview != nil || pageView.superview != nil) &&
          "refresh, neither rdbView, nor pageView is active");

   [self hideWebBrowserButtons];

   //
   [MBProgressHUD hideAllHUDsForView : self.view animated : NO];
   //

   [self startSpinner];
   //Remove error HUD.

   if (sha1Link)
      return [self loadArticleLink];

   if (rdbView.superview)
      [self loadHtmlFromReadability];
   else
      [self loadOriginalPage];
}

//________________________________________________________________________________________
- (void) composeTweetMessage
{
   // Set up the built-in twitter composition view controller.
   if (![SLComposeViewController isAvailableForServiceType : SLServiceTypeTwitter]) {
      UIAlertView *alert = [[UIAlertView alloc] initWithTitle : @"Send a twitter message:"
                                                message : @"Service is not available"
                                                delegate : nil
                                                cancelButtonTitle : @"Close"
                                                otherButtonTitles : nil];
      [alert show];
      return;
   }
   
   SLComposeViewController * const twController = [SLComposeViewController composeViewControllerForServiceType : SLServiceTypeTwitter];
   [twController setInitialText : articleLink];

   SLComposeViewControllerCompletionHandler handler = ^ (SLComposeViewControllerResult result) {
      [self dismissViewControllerAnimated:YES completion:nil];
   };
   
   twController.completionHandler = handler;
   [self presentViewController : twController animated : YES completion : nil];
}

//________________________________________________________________________________________
- (void) sendTweet
{
   //
   void (^tweetSenderBlock) (BOOL) = ^ (BOOL finished) {
      if (finished) {
         [sendOverlay removeFromSuperview];
         sendOverlay = nil;
         animatingOverlay = NO;
         [self composeTweetMessage];
      }
   };
   
   [self dismissOverlayView : tweetSenderBlock];
}

//________________________________________________________________________________________
- (void) composeFacebookMessage
{
// Set up the built-in twitter composition view controller.
   if (![SLComposeViewController isAvailableForServiceType : SLServiceTypeFacebook]) {
      UIAlertView *alert = [[UIAlertView alloc] initWithTitle : @"Send a facebook message:"
                                                message : @"Please, check facebook settings"
                                                delegate : nil
                                                cancelButtonTitle : @"Close"
                                                otherButtonTitles : nil];
      [alert show];
      return;
   }
   
   SLComposeViewController * const twController = [SLComposeViewController composeViewControllerForServiceType : SLServiceTypeFacebook];
   [twController setInitialText : articleLink];
   //
   SLComposeViewControllerCompletionHandler handler = ^ (SLComposeViewControllerResult result) {
      [self dismissViewControllerAnimated:YES completion:nil];
   };
   
   twController.completionHandler = handler;
   [self presentViewController : twController animated : YES completion : nil];
}

//________________________________________________________________________________________
- (void) sendFacebookMessage
{
   void (^fbSenderBlock) (BOOL) = ^ (BOOL finished) {
      if (finished) {
         [sendOverlay removeFromSuperview];
         sendOverlay = nil;
         animatingOverlay = NO;
         [self composeFacebookMessage];
      }
   };
   
   [self dismissOverlayView : fbSenderBlock];

}


#pragma mark - GUI.

//________________________________________________________________________________________
- (void) stopOnLinkLoadError
{
   [self stopSpinner];
   stage = LoadStage::lostNetworkConnection;
   [self showErrorHUD];
   [self addWebBrowserButtons];
}

//________________________________________________________________________________________
- (void) addSpinner
{
   if (!spinner) {
      using CernAPP::spinnerSize;

      const CGPoint spinnerOrigin = CGPointMake(self.view.frame.size.width / 2 - spinnerSize / 2, self.view.frame.size.height / 2 - spinnerSize / 2);
      spinner = [[UIActivityIndicatorView alloc] initWithFrame : CGRectMake(spinnerOrigin.x, spinnerOrigin.y, spinnerSize, spinnerSize)];
      spinner.color = [UIColor grayColor];
      //
      spinner.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight |
                                 UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
                                 UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
      //
      [self.view addSubview : spinner];
   }
}


//________________________________________________________________________________________
- (void) startSpinner
{
   [spinner setHidden : NO];
   [spinner.superview bringSubviewToFront : spinner];
   [spinner startAnimating];
}

//________________________________________________________________________________________
- (void) stopSpinner
{
   if (spinner && spinner.isAnimating) {
      [spinner stopAnimating];
      [spinner setHidden : YES];
   }
}

//________________________________________________________________________________________
- (void) addNavigationButtonsForReadabilityView
{
   assert(rdbView.superview != nil &&
          "addNavigationButtonForReadabilityView, readability view is not active");
   assert((stage == LoadStage::lostNetworkConnection || stage == LoadStage::inactive) &&
          "addNavigationButtonForReadabilityView, wrong stage");

   if (stage == LoadStage::lostNetworkConnection) {
      //Only refresh button, but we can still try to use readability.
      UIButton * const refreshBtn = [UIButton buttonWithType : UIButtonTypeCustom];
      [refreshBtn setBackgroundImage : [UIImage imageNamed : @"refresh.png"] forState : UIControlStateNormal];
      [refreshBtn addTarget : self action : @selector(refresh) forControlEvents : UIControlEventTouchUpInside];
      refreshBtn.frame = CGRectMake(0.f, 0.f, 22.f, 22.f);
      
      UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithCustomView : refreshBtn];//well, not a button but a group of them.
      self.navigationItem.rightBarButtonItem = backButton;
   } else {
      UIButton * const actionBtn = [UIButton buttonWithType : UIButtonTypeCustom];
      [actionBtn setBackgroundImage : [UIImage imageNamed : @"action.png"] forState : UIControlStateNormal];
      [actionBtn addTarget : self action : @selector(sendArticle) forControlEvents : UIControlEventTouchUpInside];
      actionBtn.frame = CGRectMake(0.f, 0.f, 22.f, 22.f);

      UIButton * const origPageBtn = [UIButton buttonWithType : UIButtonTypeCustom];
      [origPageBtn setBackgroundImage : [UIImage imageNamed : @"globe.png"] forState : UIControlStateNormal];
      [origPageBtn addTarget : self action : @selector(flipWebViews) forControlEvents : UIControlEventTouchUpInside];
      origPageBtn.frame = CGRectMake(28.f, 0.f, 22.f, 22.f);

      zoomInBtn = [UIButton buttonWithType : UIButtonTypeCustom];
      [zoomInBtn setBackgroundImage : [UIImage imageNamed : @"zoomin.png"] forState : UIControlStateNormal];
      [zoomInBtn addTarget : self action : @selector(zoomIn) forControlEvents : UIControlEventTouchUpInside];
      zoomInBtn.frame = CGRectMake(56.f, 0.f, 22.f, 22.f);
      
      zoomOutBtn = [UIButton buttonWithType : UIButtonTypeCustom];
      [zoomOutBtn addTarget : self action : @selector(zoomOut) forControlEvents : UIControlEventTouchUpInside];
      [zoomOutBtn setBackgroundImage : [UIImage imageNamed : @"zoomout.png"] forState : UIControlStateNormal];
      zoomOutBtn.frame = CGRectMake(84.f, 0.f, 22.f, 22.f);

      UIView * const parentView = [[UIView alloc] initWithFrame : CGRectMake(0.f, 0.f, 106.f, 22.f)];
      [parentView addSubview : actionBtn];
      [parentView addSubview : origPageBtn];
      [parentView addSubview : zoomInBtn];
      [parentView addSubview : zoomOutBtn];

      zoomInBtn.enabled = zoomLevel < 5 ? YES : NO;
      zoomOutBtn.enabled = zoomLevel != 0 ? YES : NO;
      
      UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithCustomView : parentView];//well, not a button but a group of them.
      self.navigationItem.rightBarButtonItem = backButton;
   }
}

//________________________________________________________________________________________
- (void) addNavigationButtonsForPageView
{
   assert(pageView.superview != nil && "addNavigationButtonsForPageView, pageView is not active");
   assert(![self isInActiveStage] && "addNavigationButtonsForPageView, wrong stage");
   
   if (stage == LoadStage::lostNetworkConnection) {
      //We have some errors while trying to load original page. Buttons depend on the
      //fact if we have a readability view or not.
      if (rdbCache) {
         //Two buttons: "Refresh" and "Readability".
         UIButton * const refreshBtn = [UIButton buttonWithType : UIButtonTypeCustom];
         [refreshBtn setBackgroundImage : [UIImage imageNamed:@"refresh.png"] forState : UIControlStateNormal];
         [refreshBtn addTarget : self action : @selector(refresh) forControlEvents : UIControlEventTouchUpInside];
         refreshBtn.frame = CGRectMake(0.f, 0.f, 22.f, 22.f);
         
         UIButton * const flipBtn = [UIButton buttonWithType : UIButtonTypeCustom];
         [flipBtn setBackgroundImage:[UIImage imageNamed:@"bookmarks.png"] forState:UIControlStateNormal];
         [flipBtn addTarget : self action : @selector(flipWebViews) forControlEvents : UIControlEventTouchUpInside];
         flipBtn.frame = CGRectMake(28.f, 0.f, 22.f, 22.f);
         
         UIView * const parentView = [[UIView alloc] initWithFrame : CGRect()];
         parentView.frame = CGRectMake(0.f, 0.f, 50.f, 22.f);
         [parentView addSubview : flipBtn];
         [parentView addSubview : refreshBtn];
         
         UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithCustomView : parentView];//well, not a button but a group of them.
         self.navigationItem.rightBarButtonItem = backButton;
      } else {
         //Only "Refresh".
         UIButton * const refreshBtn = [UIButton buttonWithType : UIButtonTypeCustom];
         [refreshBtn setBackgroundImage : [UIImage imageNamed : @"refresh.png"] forState : UIControlStateNormal];
         [refreshBtn addTarget : self action : @selector(refresh) forControlEvents : UIControlEventTouchUpInside];
         refreshBtn.frame = CGRectMake(0.f, 0.f, 22.f, 22.f);
         
         UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithCustomView : refreshBtn];//well, not a button but a group of them.
         self.navigationItem.rightBarButtonItem = backButton;
      }
   } else {
      //Inactive, view(s) were loaded ok.
      if (rdbCache) {
         UIButton * const actionBtn = [UIButton buttonWithType : UIButtonTypeCustom];
         [actionBtn setBackgroundImage : [UIImage imageNamed : @"action.png"] forState : UIControlStateNormal];
         [actionBtn addTarget : self action : @selector(sendArticle) forControlEvents : UIControlEventTouchUpInside];
         actionBtn.frame = CGRectMake(0.f, 0.f, 22.f, 22.f);
         
         UIButton * const flipBtn = [UIButton buttonWithType : UIButtonTypeCustom];
         [flipBtn setBackgroundImage:[UIImage imageNamed:@"bookmarks.png"] forState : UIControlStateNormal];
         [flipBtn addTarget : self action : @selector(flipWebViews) forControlEvents : UIControlEventTouchUpInside];
         flipBtn.frame = CGRectMake(28.f, 0.f, 22.f, 22.f);
         
         UIView * const parentView = [[UIView alloc] initWithFrame : CGRect()];
         parentView.frame = CGRectMake(0.f, 0.f, 50.f, 22.f);
         [parentView addSubview : flipBtn];
         [parentView addSubview : actionBtn];
         
         UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithCustomView : parentView];//well, not a button but a group of them.
         self.navigationItem.rightBarButtonItem = backButton;
      } else {
         //Only send.
         UIButton * const actionBtn = [UIButton buttonWithType : UIButtonTypeCustom];
         [actionBtn setBackgroundImage : [UIImage imageNamed : @"action.png"] forState : UIControlStateNormal];
         [actionBtn addTarget : self action : @selector(sendArticle) forControlEvents : UIControlEventTouchUpInside];
         actionBtn.frame = CGRectMake(0.f, 0.f, 22.f, 22.f);

         UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithCustomView : actionBtn];//well, not a button but a group of them.
         self.navigationItem.rightBarButtonItem = backButton;
      }
   }
}


//________________________________________________________________________________________
- (void) addWebBrowserButtons
{
   assert(![self isInActiveStage] && "addWebBrowserButtons, wrong stage");

   assert((pageView.superview != nil || rdbView.superview != nil) &&
          "addWebBrowserButtons, either rdbView or pageView must be active");

   if (rdbView.superview)
      [self addNavigationButtonsForReadabilityView];
   else
      [self addNavigationButtonsForPageView];
}

//________________________________________________________________________________________
- (void) addSendButtons
{
   assert(sendOverlay != nil && "addSendButtons, sendOverlay is nil");
   
   //Harcoded geometry :) But it's ... ok :)
   CGRect frame = CGRectMake(10.f, 60.f, 80.f, 80.f);

   PictureButtonView * const twBtn = [[PictureButtonView alloc] initWithFrame : frame image : [UIImage imageNamed : @"Twitter.png"]];
   [twBtn addTarget : self selector : @selector(sendTweet)];
   [sendOverlay addSubview : twBtn];
   
   frame.origin.x = 100.f;
   PictureButtonView * const fbBtn = [[PictureButtonView alloc] initWithFrame : frame image : [UIImage imageNamed : @"Facebook.png"]];
   [fbBtn addTarget : self selector : @selector(sendFacebookMessage)];
   [sendOverlay addSubview : fbBtn];
   
   frame.origin.x = 190.f;
   PictureButtonView * const emBtn = [[PictureButtonView alloc] initWithFrame : frame image : [UIImage imageNamed : @"Email-01.png"]];
   [emBtn addTarget : self selector : @selector(sendEmail)];
   [sendOverlay addSubview : emBtn];

}

//________________________________________________________________________________________
- (void) hideWebBrowserButtons
{
   self.navigationItem.rightBarButtonItem = nil;
}

//________________________________________________________________________________________
- (void) switchToPageView
{
   //Non-animated switch.
   if (rdbView.superview)
      [rdbView removeFromSuperview];
   if (!pageView.superview)
      [containerView addSubview : pageView];
   
   [self.slidingViewController.panGesture requireGestureRecognizerToFail : pageView.scrollView.panGestureRecognizer];
   
   if (!spinner.hidden)
      [spinner.superview bringSubviewToFront : spinner];
}

//________________________________________________________________________________________
-(void) switchToRdbView
{
   //Non-animated switch.
   if (pageView.superview)
      [pageView removeFromSuperview];
   if (!rdbView.superview)
      [containerView addSubview : rdbView];

   [self.slidingViewController.panGesture requireGestureRecognizerToFail : rdbView.scrollView.panGestureRecognizer];

   if (!spinner.hidden)
      [spinner.superview bringSubviewToFront : spinner];
}

#pragma mark - OverlayViewDelegate

//________________________________________________________________________________________
- (void) dismissOverlayView : (void (^)(BOOL finished)) block
{
   //block MUST remove sendOverlay view (but I can not check/force it).
   animatingOverlay = YES;

   CGRect frame = sendOverlay.frame;

   frame.origin.y = -frame.size.height;

   if (block) {
      [UIView animateWithDuration : 0.25f animations : ^ {
          sendOverlay.frame = frame;
       }
       completion : block];
   } else {
      [UIView animateWithDuration : 0.25f animations : ^ {
         sendOverlay.frame = frame;
       } completion:^(BOOL finished) {
          if (finished) {
             [sendOverlay removeFromSuperview];
             sendOverlay = nil;
             animatingOverlay = NO;
          }
       }];
   }
}

#pragma mark - MFMailComposeViewController delegate

//___________________________________________________________
- (void) mailComposeController : (MFMailComposeViewController *)controller didFinishWithResult : (MFMailComposeResult)result error : (NSError *)error
{
   [self becomeFirstResponder];//???
   [self dismissViewControllerAnimated : YES completion : nil];
}

#pragma mark - MBProgressHUD

//________________________________________________________________________________________
- (void) showErrorHUD
{
   noConnectionHUD = [MBProgressHUD showHUDAddedTo : self.view animated : NO];
   noConnectionHUD.color = [UIColor redColor];
   noConnectionHUD.mode = MBProgressHUDModeText;
   noConnectionHUD.labelText = @"Network error";
   noConnectionHUD.removeFromSuperViewOnHide = YES;
}

#pragma mark - Interface rotation.

//________________________________________________________________________________________
- (BOOL) shouldAutorotate
{
   if (apnLoaded && UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
      return YES;

   if ((rdbCache && rdbView.superview) || (pageLoaded && pageView.superview))
      return YES;
   
   return NO;
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

   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
      return;//We do not hide a navigation bar on iPad.

   if (UIInterfaceOrientationIsLandscape(toInterfaceOrientation)) {
      [self.navigationController.view removeGestureRecognizer : self.slidingViewController.panGesture];
      [self.navigationController setNavigationBarHidden : YES];
   } else {
      [self.navigationController.view addGestureRecognizer : self.slidingViewController.panGesture];
      [self.navigationController setNavigationBarHidden : NO];
   }
   
   if (CernAPP::SystemVersionGreaterThanOrEqualTo(@"7.0")) {
      UIEdgeInsets insets = {};
      if (UIInterfaceOrientationIsPortrait(toInterfaceOrientation))
         insets.top = self.navigationController.navigationBar.frame.size.height + 20.f;

      rdbView.scrollView.contentInset = insets;
      pageView.scrollView.contentInset = insets;
   }

}

//________________________________________________________________________________________
- (void) didRotateFromInterfaceOrientation : (UIInterfaceOrientation) fromInterfaceOrientation
{
#pragma unused(fromInterfaceOrientation)
   [self.view layoutSubviews];
}

#pragma mark - Core Data.

//________________________________________________________________________________________
- (BOOL) purgeReadabilityCache
{
   AppDelegate * const appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
   if (NSManagedObjectContext * const context = appDelegate.managedObjectContext) {
      NSFetchRequest * const request = [[NSFetchRequest alloc] init];
      [request setEntity : [NSEntityDescription entityForName : @"RDBArticle" inManagedObjectContext : context]];
      [request setIncludesPropertyValues : NO]; //only fetch the managedObjectID

      NSError * error = nil;
      NSArray * const allArticles = [context executeFetchRequest : request error : &error];
      if (error)
         return NO;
      
      
   
      for (NSManagedObject * article in allArticles)
        [context deleteObject : article];

      NSError *saveError = nil;
      [context save : &saveError];
      
      return !saveError;
   }

   return NO;
}

//________________________________________________________________________________________
- (BOOL) checkReadabilityCache
{
   //Check the current "size". This is not the real estimation, of course, but just an attempt to make one.
   
   //I'm calculating the total size of cached articles, if it's "already big enough", I'm
   //deleteing all the previous information.
   
   AppDelegate * const appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;

   if (NSManagedObjectContext * const context = appDelegate.managedObjectContext) {
      NSEntityDescription * const entityDesc = [NSEntityDescription entityForName : @"RDBArticle"
                                                                    inManagedObjectContext : context];
      NSFetchRequest * const request = [[NSFetchRequest alloc] init];
      [request setEntity : entityDesc];
      
      NSError *error = nil;
      const NSUInteger nCachedArticles = [context countForFetchRequest : request error : &error];
      if (error)
         return NO;
      
      if (nCachedArticles >= 50)
         return [self purgeReadabilityCache];
      
      return YES;
   }
   
   return NO;
}

//________________________________________________________________________________________
- (void) saveReadabilityCache
{
   assert(rdbCache != nil && "saveReadabilityCache, rdbCache is nil");
   assert(articleID != nil && "saveReadabilityCache, articleID is nil");

   if (![responseEncoding isEqualToString : @"utf-8"])//TODO.
      return;

 //  if ([self checkReadabilityCache]) {
      //TODO: this requires serious checks - if I really have to save as a binary data and
      //if I have any benefits at all.
      
   AppDelegate * const appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;

   if (NSManagedObjectContext * const context = appDelegate.managedObjectContext) {
      //TODO: actually, I have to use responseEncoding to check, if it's really utf-8.
      NSData * const binaryData = [rdbCache dataUsingEncoding : NSUTF8StringEncoding];

      NSManagedObject * const saveItem = [NSEntityDescription insertNewObjectForEntityForName : @"RDBArticle"
                                                              inManagedObjectContext : context];
      if (saveItem) {
         [saveItem setValue : articleID forKey : @"articleID"];
         [saveItem setValue : binaryData forKey : @"articleData"];

         NSError *error = nil;
         [context save : &error];
      }
   }
 //  }
}

//________________________________________________________________________________________
- (void) getReadabilityCache
{
   assert(articleID != nil && "getReadabilityCache:, parameter 'articleID' is nil");
   
   AppDelegate * const appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;

   if (NSManagedObjectContext * const context = appDelegate.managedObjectContext) {
      NSEntityDescription * const entityDesc = [NSEntityDescription entityForName : @"RDBArticle"
                                                                    inManagedObjectContext : context];
      
      NSFetchRequest * const request = [[NSFetchRequest alloc] init];
      [request setEntity : entityDesc];
      
      NSPredicate * const pred = [NSPredicate predicateWithFormat : @"(articleID = %@)", articleID];
      [request setPredicate : pred];
      
      NSError *error = nil;
      NSArray * const objects = [context executeFetchRequest : request error : &error];
      
      if (!error && objects && objects.count) {
         NSManagedObject * const cache = (NSManagedObject *)objects[0];
         NSData * const binaryData = [cache valueForKey : @"articleData"];
         if (binaryData && binaryData.length)
            rdbCache = [[NSString alloc] initWithBytes : binaryData.bytes length : binaryData.length encoding : NSUTF8StringEncoding];
      }
   }
}

//________________________________________________________________________________________
+ (BOOL) articleCached : (NSString *) articleID
{
   assert(articleID != nil && "articleCached:, parameter 'articleID' is nil");
   
   AppDelegate * const appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;

   if (NSManagedObjectContext * const context = appDelegate.managedObjectContext) {
      NSEntityDescription * const entityDesc = [NSEntityDescription entityForName : @"RDBArticle"
                                                                    inManagedObjectContext : context];
      
      NSFetchRequest * const request = [[NSFetchRequest alloc] init];
      [request setEntity : entityDesc];
      
      NSPredicate * const pred = [NSPredicate predicateWithFormat : @"(articleID = %@)", articleID];
      [request setPredicate : pred];
      [request setIncludesPropertyValues : NO]; //only fetch the managedObjectID
      
      NSError *error = nil;
      NSArray * const objects = [context executeFetchRequest : request error : &error];
      
      if (!error && objects && objects.count)
         return YES;
   }
   
   return NO;
}

#pragma mark - ConnectionController.

//________________________________________________________________________________________
- (void) cancelAnyConnections
{
   [self stopTimer];

   if (rdbView.isLoading) {
      [rdbView stopLoading];
      rdbView.delegate = nil;
   }
   
   if (pageView.isLoading) {
      [pageView stopLoading];
      pageView.delegate = nil;
   }
   
   [self stopSpinner];
   
   if (currentConnection) {
      [currentConnection cancel];
      currentConnection = nil;
   }

   stage = LoadStage::inactive;
   status = 200;
}

#pragma mark - Timeout guard.

//________________________________________________________________________________________
- (void) startTimer
{
   assert(timeoutGuard == nil && "startTime, timer is active already");
   timeoutGuard = [NSTimer scheduledTimerWithTimeInterval : 60.f target : self selector : @selector(timeoutHandler) userInfo : nil repeats : NO];
}

//________________________________________________________________________________________
- (void) stopTimer
{
   [timeoutGuard invalidate];
   timeoutGuard = nil;
}

//________________________________________________________________________________________
- (void) timeoutHandler
{
   //This can happen ONLY when we're loading either an html from the Readability or original page.
   //We consider timeout as an error and stop loading anything at all.
   if (stage == LoadStage::originalPageLoad) {
      [self webView : pageView didFailLoadWithError : nil];
   } else if (stage == LoadStage::rdbCacheLoad) {
      [self webView : rdbView didFailLoadWithError : nil];
   }
   
   timeoutGuard = nil;
}

#pragma mark - UIScrollViewDelegate

//________________________________________________________________________________________
- (UIView *) viewForZoomingInScrollView : (UIScrollView *) scrollView
{
   return nil;
}

#pragma mark - ECSlidingViewController.

//________________________________________________________________________________________
- (IBAction) revealMenu : (id) sender
{
#pragma unused(sender)
   [self.slidingViewController anchorTopViewTo : ECRight];
}

@end
