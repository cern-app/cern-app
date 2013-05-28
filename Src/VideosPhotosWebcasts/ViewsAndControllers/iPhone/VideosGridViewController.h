//
//  VideosGridViewController.h
//  CERN App
//
//  Created by Eamon Ford on 8/9/12.
//  Copyright (c) 2012 CERN. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "ConnectionController.h"
#import "CernMediaMARCParser.h"
#import "HUDRefreshProtocol.h"
#import "ImageDownloader.h"
#import "MBProgressHUD.h"

@interface VideosGridViewController : UICollectionViewController<CernMediaMarcParserDelegate, ImageDownloaderDelegate, ConnectionController,
                                                                 UICollectionViewDataSource, UICollectionViewDelegate, HUDRefreshProtocol>
{
@protected
   NSMutableArray *videoMetadata;
   NSMutableDictionary *videoThumbnails;
   NSMutableDictionary *imageDownloaders;
}

- (IBAction)refresh : (id) sender;
- (IBAction) revealMenu : (id) sender;

//HUD/Refresh protocol.
@property (nonatomic, strong) MBProgressHUD *noConnectionHUD;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;

@end
