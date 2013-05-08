//
//  StaticInfoTileViewController.h
//  CERN
//
//  Created by Timur Pocheptsov on 5/8/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "ConnectionController.h"
#import "TileViewController.h"

@interface StaticInfoTileViewController : TileViewController<ConnectionController>

- (void) setDataSource : (NSArray *) data;

@end
