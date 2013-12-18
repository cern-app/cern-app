//
//  InitialSlidingViewController.m
//  ECSlidingViewController
//
//  Created by Michael Enriquez on 1/25/12.
//  Copyright (c) 2012 EdgeCase. All rights reserved.
//

//This class is a central for our app - it's our sliding view controller,
//which hosts everything else inside. The code modified and adapted for CERN.app
//by Timur Pocheptsov.

#import <cassert>

#import "InitialSlidingViewController.h"
#import "ArticleDetailViewController.h"
#import "CAPPNewsPageViewController.h"
#import "MenuNavigationController.h"
#import "NewsTableViewController.h"
#import "NewsFeedViewController.h"
#import "StoryboardIdentifiers.h"
#import "ContentProviders.h"
#import "DeviceCheck.h"
#import "AppDelegate.h"
#import "GUIHelpers.h"

@implementation InitialSlidingViewController

//________________________________________________________________________________________
- (void) loadFirstNewsFeed : (UIViewController *) aController skip : (NSString *) feedToSkip
{
   assert(aController != nil && "loadFirstNewsFeed:, parameter 'aController' is nil");

   NSString * const path = [[NSBundle mainBundle] pathForResource : @"MENU" ofType : @"plist"];
   NSDictionary * const plistDict = [NSDictionary dictionaryWithContentsOfFile : path];
   assert(plistDict != nil && "viewDidLoad, no dictionary or MENU.plist found");

   id objBase = plistDict[@"Menu Contents"];
   assert([objBase isKindOfClass : [NSArray class]] &&
          "viewDidLoad, object for the key 'Menu Contents' was not found or has a wrong type");

   NSArray * const menuContents = (NSArray *)objBase;
   assert(menuContents.count != 0 && "viewDidLoad, menu contents array is empty");

   //We are looking for either a tweet or a news feed in our list.
   NSDictionary *feedDict = nil;
   
   for (id item in menuContents) {
      assert([item isKindOfClass : [NSDictionary class]] && "loadFirstNewsFeed:, item in an array has a wrong type");
      NSDictionary * const menuItemDict = (NSDictionary *)item;

      id objBase = menuItemDict[@"Category name"];
      assert([objBase isKindOfClass : [NSString class]] &&
             "loadFirstNewsFeed:, 'Category Name' either not found, or has a wrong type");
   
      NSString * const catName = (NSString *)objBase;
      if ([catName isEqualToString : @"Feed"] || [catName isEqualToString : @"Tweet"]) {
         assert([menuItemDict[@"Name"] isKindOfClass : [NSString class]] &&
                "loadFirstNewsFeed:, 'Name' not found or has a wrong type");
         //It's a feed at the top level.
         if (!feedToSkip || ![feedToSkip isEqualToString : (NSString *)menuItemDict[@"Name"]])
            feedDict = menuItemDict;
      } else if ([catName isEqualToString : @"Menu group"]) {
         //Scan the menu group for a feed.
         assert([menuItemDict[@"Items"] isKindOfClass : [NSArray class]] &&
                "loadFirstNewsFeed:, 'Items' not found or has a wrong type");

         NSArray * const groupItems = (NSArray *)menuItemDict[@"Items"];
         for (id info in groupItems) {
            assert([info isKindOfClass : [NSDictionary class]] &&
                   "loadFirstNewsFeed:, item has a wrong type");

            NSDictionary * const childItemInfo = (NSDictionary *)info;
            assert([childItemInfo[@"Category name"] isKindOfClass : [NSString class]] &&
                   "'Category name' not found or has a wrong type");

            NSString * const childCategoryName = (NSString *)childItemInfo[@"Category name"];
            if ([childCategoryName isEqualToString : @"Feed"] || [childCategoryName isEqualToString : @"Tweet"]) {
               assert([childItemInfo[@"Name"] isKindOfClass : [NSString class]] &&
                      "loadFirstNewsFeed:, 'Name' not found or has a wrong type");
               //It's a feed at the top level.
               if (!feedToSkip || ![feedToSkip isEqualToString : (NSString *)childItemInfo[@"Name"]]) {
                  feedDict = childItemInfo;
                  break;
               }
            }
         }
      }

      if (feedDict)
         break;
   }

   assert(feedDict != nil && "loadFirstNewsFeed:, no feed/tweet found");
   
   assert([feedDict[@"Name"] isKindOfClass : [NSString class]] &&
          "loadFirstNewsFeed:, 'Name' not found or has a wrong type");
   assert([feedDict[@"Url"] isKindOfClass : [NSString class]] &&
          "loadFirstNewsFeed:, 'Url' not found or has a wrong type");
   assert([feedDict[@"ItemID"] isKindOfClass : [NSNumber class]] &&
          "loadFirstNewsFeed:, ItemID is either nil or has a wrong type");
   const NSUInteger apnID = [(NSNumber *)feedDict[@"ItemID"] unsignedIntegerValue];
   assert(apnID > 0 && "loadFirstNewsFeed:, ItemID is invalid");

   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
      assert([aController isKindOfClass : [NewsFeedViewController class]] &&
             "loadFirstNewsFeed:, controller has a wrong type");
      NewsFeedViewController * const tileController = (NewsFeedViewController *)aController;
      tileController.navigationItem.title = (NSString *)feedDict[@"Name"];
      tileController.feedCacheID = [FeedProvider feedCacheID : feedDict];
      tileController.apnID = apnID;
      [tileController setFeedURLString : (NSString *)feedDict[@"Url"]];
   } else {
      assert([aController isKindOfClass : [NewsTableViewController class]] &&
             "loadFirstNewsFeed:, controller has a wrong type");
      NewsTableViewController * const tableController = (NewsTableViewController *)aController;
      tableController.navigationItem.title = (NSString *)feedDict[@"Name"];
      tableController.feedCacheID = [FeedProvider feedCacheID : feedDict];
      tableController.apnID = apnID;
      [tableController setFeedURLString : (NSString *)feedDict[@"Url"]];
   }
}

//________________________________________________________________________________________
- (void) initAPNViewController : (NSString *) sha1Link
{
   assert(sha1Link != nil && sha1Link.length == 40 && "initAPNViewController:, parameter 'sha1Link' is invalid");

   UIStoryboard *storyboard = nil;
   
   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
      NSString * const fileName = CernAPP::SystemVersionGreaterThanOrEqualTo(@"7.0") ? @"iPhone_iOS7" : @"iPhone";
      storyboard = [UIStoryboard storyboardWithName : fileName bundle : nil];
   } else if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
      NSString * const fileName = CernAPP::SystemVersionGreaterThanOrEqualTo(@"7.0") ? @"iPad_iOS7" : @"iPad";
      storyboard = [UIStoryboard storyboardWithName : fileName bundle : nil];
      //For iPad, limit the visible width of under left view.
      self.shouldAllowPanningPastAnchor = NO;
      self.anchorLeftRevealAmount = CernAPP::menuWidthPad;
   }

   assert(storyboard != nil && "iniAPNViewController:, storyboard is nil");

   MenuNavigationController * const top = (MenuNavigationController *)[storyboard instantiateViewControllerWithIdentifier :
                                                                       CernAPP::ArticleDetailStandaloneControllerID];
   assert([top.topViewController isKindOfClass : [ArticleDetailViewController class]] &&
          "viewDidLoad:, top view controller is either nil or has a wrong type");
   [(ArticleDetailViewController *)top.topViewController setSha1Link : sha1Link];
   self.topViewController = top;
}

//________________________________________________________________________________________
- (void) initSlidingViewController : (NSString *) feedToSkip
{
   assert([[UIApplication sharedApplication].delegate isKindOfClass : [AppDelegate class]] &&
          "initSlidingViewController:, application delegate has a wrong type");
   AppDelegate * const appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
   
   //Test:
   //appDelegate.APNdictionary = @{@"sha1" : @"c2f3136ac47391222ec57726c802af3ad8f60293"};
   
   //Special case: we were started from a notification center (or just from a notification).
   if (!feedToSkip && appDelegate.APNdictionary) {//UGLY, but feedToSkip means we're reloading after a memory warning, forget about any notifications!
      NSString * const sha1Hash = (NSString *)appDelegate.APNdictionary[@"sha1"];
      if (sha1Hash && sha1Hash.length == 40) {
         [self initAPNViewController : sha1Hash];
         appDelegate.APNdictionary = nil;
         [UIApplication sharedApplication].applicationIconBadgeNumber = 0;
         return;
      }
   }
   
   if (appDelegate.APNdictionary) {
      //Ignore.
      appDelegate.APNdictionary = nil;
      [UIApplication sharedApplication].applicationIconBadgeNumber = 0;
   }

   UIStoryboard *storyboard = nil;
   
   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
      NSString * const fileName = CernAPP::SystemVersionGreaterThanOrEqualTo(@"7.0") ? @"iPhone_iOS7" : @"iPhone";
      storyboard = [UIStoryboard storyboardWithName : fileName bundle : nil];
   } else if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
      NSString * const fileName = CernAPP::SystemVersionGreaterThanOrEqualTo(@"7.0") ? @"iPad_iOS7" : @"iPad";
      storyboard = [UIStoryboard storyboardWithName : fileName bundle : nil];
      //For iPad, limit the visible width of under left view.
      self.shouldAllowPanningPastAnchor = NO;
      self.anchorLeftRevealAmount = CernAPP::menuWidthPad;
   }

   assert(storyboard != nil && "initSlidingViewController:, storyboard is nil");

   MenuNavigationController * top = nil;

   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
      top = (MenuNavigationController *)[storyboard instantiateViewControllerWithIdentifier :
                                                    CernAPP::TableNavigationControllerNewsID];
      assert([top.topViewController isKindOfClass : [NewsTableViewController class]] &&
             "initSlidingViewController:, top view controller is either nil or has a wrong type");
      //The very first view a user see - is a news table. We create a navigation controller
      //with such a table here, also, we have to add a news feed here.
   } else {
      //
      /*
      top = [storyboard instantiateViewControllerWithIdentifier : CernAPP::CAPPNewsPageViewControllerID];
      assert([top.topViewController isKindOfClass : [CAPPNewsPageViewController class]] &&
             "initSlidingViewController:, top view controller is either nil or has a wrong type");
      CAPPNewsPageViewController * const c = (CAPPNewsPageViewController *)top.topViewController;
      c.feedCacheID = @"General1";
      c.apnID = 1;
      self.topViewController = top;
      return;
      */
      //
      top = (MenuNavigationController *)[storyboard instantiateViewControllerWithIdentifier :
                                                    CernAPP::FeedTileViewControllerID];
      assert([top.topViewController isKindOfClass : [NewsFeedViewController class]] &&
             "initSlidingViewController:, top view controller is either nil or has a wrong type");
   }

   [self loadFirstNewsFeed : top.topViewController skip : feedToSkip];
   self.topViewController = top;
}

//________________________________________________________________________________________
- (void) viewDidLoad
{
   [super viewDidLoad];
  
   [self initSlidingViewController : nil];
}

#pragma mark - Low memory warnings.

//________________________________________________________________________________________
- (void) didReceiveMemoryWarning
{
 //  if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
   assert([[UIApplication sharedApplication].delegate isKindOfClass : [AppDelegate class]] &&
          "didReceiveMemoryWarning, app delegate has a wrong type");
   
   [(AppDelegate *)[UIApplication sharedApplication].delegate clearFeedCache]; 
   [self initSlidingViewController : @"General"];
}

//________________________________________________________________________________________
- (BOOL) shouldAutorotate
{
   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone && [self underLeftShowing])
      return NO;
   
   return [self.topViewController shouldAutorotate];
}

//________________________________________________________________________________________
- (NSUInteger) supportedInterfaceOrientations
{
   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
      if ([self underLeftShowing])
         return UIInterfaceOrientationMaskPortrait;
   }

   return [self.topViewController supportedInterfaceOrientations];
}



@end
