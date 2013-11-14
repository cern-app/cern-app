//
//  NewsFeedViewController.h
//  CERN
//
//  Created by Timur Pocheptsov on 4/17/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import "ConnectionController.h"
#import "APNEnabledController.h"
#import "FeedParserOperation.h"
#import "ThumbnailDownloader.h"
#import "TileViewController.h"
#import "ImageDownloader.h"

//NewsFeedViewController - shows feed items on a "newspaper's page".
//Created by in two steps:
//1) - (id) initWithCoder : (NSCoder *) aDecoder; //This is called by UIKit.
//and the next function must be called before view is presented -
//2) - (void) setFeedURLString : (NSString) urlString;

//Controller works in several steps:
//1) download the feed.
//2) parse the feed.
//3) download images for a page (on demand).
//
//MWFeedParser can download the xml asynchronously, but after that
//it immediately starts parsing on a main thread. This parsing
//can take up to several seconds, making the app non-responsive.
//So, I'll MWFeedParser in a separate thread (NSOperation) in a synchronous mode
//(not to create another thread from a background thread).

@interface NewsFeedViewController : TileViewController<ThumbnailDownloaderDelegate, ConnectionController,
                                                       FeedParserOperationDelegate, APNEnabledController>
{
@protected
   NSMutableDictionary *downloaders;//image downloaders.
   NSArray *feedCache;
   FeedParserOperation *parserOp;
}

- (void) setFeedURLString : (NSString *) urlString;
- (void) setFilters : (NSObject *) filters;

//Reachability.
- (BOOL) hasConnection;

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
