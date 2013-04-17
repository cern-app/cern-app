//
//  NewsFeedViewController.h
//  CERN
//
//  Created by Timur Pocheptsov on 4/17/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//


#import "PageControllerProtocol.h"
#import "ConnectionController.h"
#import "TileViewController.h"
#import "HUDRefreshProtocol.h"
#import "ImageDownloader.h"
#import "RSSAggregator.h"

@interface NewsFeedViewController : TileViewController<HUDRefreshProtocol, RSSAggregatorDelegate, PageController,
                                                       ImageDownloaderDelegate, ConnectionController,
                                                       UIScrollViewDelegate>
{
@protected
   NSMutableDictionary *imageDownloaders;
   NSArray *feedCache;
}

//Aux.
- (void) createPages;
- (void) addTileTapObserver;
- (void) initTilesFromCache;
- (void) setTilesLayoutHints;

@property (nonatomic, strong) RSSAggregator *aggregator;
@property (nonatomic, copy) NSString *feedStoreID;//Cache ID.

//HUD/GUI
@property (nonatomic, strong) MBProgressHUD *noConnectionHUD;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;

- (void) hideNavBarSpinner;


@end
