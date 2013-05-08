//
//  PhotosViewController.h
//  CERN App
//
//  Created by Eamon Ford on 6/27/12.
//  Copyright (c) 2012 CERN. All rights reserved.
//

#import "ConnectionController.h"
#import "PhotoDownloader.h"
#import "MWPhotoBrowser.h"
#import "MBProgressHUD.h"

@interface PhotosGridViewController : UICollectionViewController <PhotoDownloaderDelegate, MBProgressHUDDelegate, MWPhotoBrowserDelegate,
                                                                  UICollectionViewDataSource, UICollectionViewDelegate,
                                                                  ConnectionController>

@property (nonatomic, strong) PhotoDownloader *photoDownloader;

- (void) refresh;

- (IBAction) reloadImages : (id) sender;
- (IBAction) revealMenu : (id) sender;

@end
