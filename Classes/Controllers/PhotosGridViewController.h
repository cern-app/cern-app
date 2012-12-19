//
//  PhotosViewController.h
//  CERN App
//
//  Created by Eamon Ford on 6/27/12.
//  Copyright (c) 2012 CERN. All rights reserved.
//

#import "AQGridViewController.h"
#import "AQGridView.h"
#import "AQGridViewCell.h"
#import "CernMediaMARCParser.h"
#import "MWPhotoBrowser.h"
#import "MBProgressHUD.h"
#import "PhotoDownloader.h"

@interface PhotosGridViewController : AQGridViewController<AQGridViewDataSource, AQGridViewDelegate, MWPhotoBrowserDelegate, PhotoDownloaderDelegate, MBProgressHUDDelegate>

@property (nonatomic, strong) PhotoDownloader *photoDownloader;

- (void) refresh;

@end
