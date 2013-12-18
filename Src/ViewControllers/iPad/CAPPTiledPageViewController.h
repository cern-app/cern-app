//
//  CAPPTiledPageViewController.h
//  CERN
//
//  Created by Timur Pocheptsov on 18/12/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "HUDRefreshProtocol.h"
#import "CAPPPageControl.h"
#import "TiledPage.h"

@interface CAPPTiledPageViewController : UIViewController<UIScrollViewDelegate, HUDRefreshProtocol, CAPPPageControlDelegate> {
@protected
   //Data items: can be feed entries or grouped feed entries (for the bulletin).
   NSMutableArray *dataItems;
   NSUInteger nPages;
   
   UIView<TiledPage> *prevPage;
   UIView<TiledPage> *currPage;
   UIView<TiledPage> *nextPage;
   
   BOOL delayedRefresh;
}

@property (nonatomic, weak) IBOutlet CAPPPageControl *pageControl;
@property (nonatomic, weak) IBOutlet UIScrollView *parentScroll;

//After dataItems were loaded (either the first time
//or after refreshing, this function (re)sets pages.
- (void) setPagesData;//To be overriden.

//At the moment we load page data (for example images)
//only for a visible page.
- (void) loadVisiblePageData;//To be overriden.

//Set the page's geometry and (probably) tiles' geometry also.
- (void) layoutPages : (BOOL) layoutTiles;

//Using dataItems and page layout identify, how many items
//fit the page.
- (NSRange) findItemRangeForPage : (NSUInteger) pageIndex;

//ECSlidingViewController:
- (IBAction) revealMenu : (id) sender;

//HUDRefreshProtocol.
@property (nonatomic, strong) MBProgressHUD *noConnectionHUD;//Error messages.
@property (nonatomic, strong) UIActivityIndicatorView *spinner;

//To be overriden:
- (void) refreshAfterDelay;
- (BOOL) canShowAlert;

@end
