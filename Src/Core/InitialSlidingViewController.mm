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
#import "MenuNavigationController.h"
#import "NewsTableViewController.h"
#import "NewsFeedViewController.h"
#import "StoryboardIdentifiers.h"
#import "ContentProviders.h"
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
   
   NSString * storeID = @"";
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
         if (!feedToSkip || ![feedToSkip isEqualToString : (NSString *)menuItemDict[@"Name"]]) {
            storeID = (NSString *)menuItemDict[@"Name"];
            feedDict = menuItemDict;
         }
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
                  storeID = [(NSString *)menuItemDict[@"Name"] stringByAppendingString:(NSString *)feedDict[@"Name"]];
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
      tileController.feedApnID = apnID;
      [tileController setFeedURLString : (NSString *)feedDict[@"Url"]];
   } else {
      assert([aController isKindOfClass : [NewsTableViewController class]] &&
             "loadFirstNewsFeed:, controller has a wrong type");
      NewsTableViewController * const tableController = (NewsTableViewController *)aController;
      tableController.navigationItem.title = (NSString *)feedDict[@"Name"];
      tableController.feedCacheID = [FeedProvider feedCacheID : feedDict];
      tableController.feedApnID = apnID;
      [tableController setFeedURLString : (NSString *)feedDict[@"Url"]];
   }
}

//________________________________________________________________________________________
- (void) initSlidingViewController : (NSString *) feedToSkip
{
   UIStoryboard *storyboard = nil;
   
   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
      storyboard = [UIStoryboard storyboardWithName : @"iPhone" bundle : nil];
   else if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
      storyboard = [UIStoryboard storyboardWithName : @"iPad" bundle : nil];
      //For iPad, limit the visible width of under left view.
      self.shouldAllowPanningPastAnchor = NO;
      self.anchorLeftRevealAmount = CernAPP::menuWidthPad;
   }

   assert(storyboard != nil && "viewDidLoad, storyboard is nil");

   MenuNavigationController * top = nil;

   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
      top = (MenuNavigationController *)[storyboard instantiateViewControllerWithIdentifier :
                                                    CernAPP::TableNavigationControllerNewsID];
      assert([top.topViewController isKindOfClass : [NewsTableViewController class]] &&
             "viewDidLoad:, top view controller is either nil or has a wrong type");
      //The very first view a user see - is a news table. We create a navigation controller
      //with such a table here, also, we have to add a news feed here.
   } else {
      top = (MenuNavigationController *)[storyboard instantiateViewControllerWithIdentifier :
                                                    CernAPP::FeedTileViewControllerID];
      assert([top.topViewController isKindOfClass : [NewsFeedViewController class]] &&
             "viewDidLoad:, top view controller is either nil or has a wrong type");
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
