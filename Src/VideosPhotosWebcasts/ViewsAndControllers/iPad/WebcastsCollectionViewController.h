//
//  WebcastsViewController.h
//  CERN
//
//  Created by Timur Pocheptsov on 5/24/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "ConnectionController.h"
#import "ImageDownloader.h"
#import "MWFeedParser.h"

@interface WebcastsCollectionViewController : UICollectionViewController<MWFeedParserDelegate, ConnectionController,
                                                                         ImageDownloaderDelegate>

- (void) setControllerData : (NSArray *) dataItems;

@end
