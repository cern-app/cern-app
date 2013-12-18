//
//  CAPPNewsPageViewController.h
//  CERN
//
//  Created by Timur Pocheptsov on 18/12/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import "CAPPTiledPageViewController.h"
#import "APNEnabledController.h"

@interface CAPPNewsPageViewController : CAPPTiledPageViewController { //<APNEnabledController> {
@protected
   NSMutableDictionary *downloaders;//image downloaders.
   NSArray *feedCache;
   //FeedParserOperation *parserOp;
}

//Aux. methods, can be overriden.
//Create views: prevPage, currPage, nextPage.
- (void) createPages;

//Add self as a notification observer for tile tap notification.
- (void) addTileTapObserver;

//If controller supports caching, read data from the cache and fill pages.
- (BOOL) initTilesFromDBCache;
- (BOOL) initTilesFromAppCache;

//This is a trick to make tiles' layout more interesting depending on data.
- (void) setTilesLayoutHints;

//When pages were loaded from the cache and we update from the real feed, spinner is shown in a nav. bar.
- (void) hideNavBarSpinner;

@property (nonatomic, copy) NSString *feedCacheID;

//HUD/UI
- (IBAction) refresh : (id) sender;//The action for a nav. bar button.

//APNEnabledController.
@property (nonatomic) NSUInteger apnID;
@property (nonatomic) NSUInteger apnItems;

@end
