//
//  WebcastsGridViewController.h
//  CERN App
//
//  Created by Eamon Ford on 8/16/12.
//  Copyright (c) 2012 CERN. All rights reserved.
//


#import "ConnectionController.h"
#import "HUDRefreshProtocol.h"
#import "ImageDownloader.h"
#import "WebcastsParser.h"


@interface WebcastsGridViewController : UICollectionViewController<WebcastsParserDelegate, ConnectionController,
                                                                   ImageDownloaderDelegate, HUDRefreshProtocol>

- (IBAction) refresh : (id) sender;
- (IBAction) revealMenu : (id) sender;

//HUD/Refresh protocol.
@property (nonatomic, strong) MBProgressHUD *noConnectionHUD;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;


@end
