//
//  BulletinIssueTableViewController.h
//  CERN
//
//  Created by Timur Pocheptsov on 1/21/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "ConnectionController.h"
#import "ImageDownloader.h"

@class BulletinTableViewController;
@class MWFeedItem;

@interface BulletinIssueTableViewController : UITableViewController<UITableViewDataSource, UITableViewDelegate,
                                                                    ImageDownloaderDelegate, ConnectionController>

@property (nonatomic) __weak NSArray *tableData;
@property (nonatomic) __weak BulletinTableViewController *prevController;

- (void) reloadRowFor : (MWFeedItem *) article;

@end
