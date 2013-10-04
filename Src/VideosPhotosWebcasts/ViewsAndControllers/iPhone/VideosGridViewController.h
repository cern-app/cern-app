//
//  VideosGridViewController.h
//  CERN App
//
//  Created by Eamon Ford on 8/9/12.
//  Copyright (c) 2012 CERN. All rights reserved.
//

//Modified for CERN.app by Timur Pocheptsov.
//AQGridView controller was replaced by UICollectionViewController.

#import <UIKit/UIKit.h>

#import "ConnectionController.h"
#import "HUDRefreshProtocol.h"
#import "ImageDownloader.h"
#import "MBProgressHUD.h"
#import "CDSParser.h"

@interface VideosGridViewController : UICollectionViewController<CDSParserOperationDelegate, ImageDownloaderDelegate, ConnectionController,
                                                                 UICollectionViewDataSource, UICollectionViewDelegate, HUDRefreshProtocol>
{
@protected
   NSArray *videoMetadata;
   NSMutableDictionary *videoThumbnails;
   NSMutableDictionary *imageDownloaders;
}

//HUD/Refresh protocol.
@property (nonatomic, strong) MBProgressHUD *noConnectionHUD;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;

@end
