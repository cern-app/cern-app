//
//  BulletinTableViewController.h
//  CERN
//
//  Created by Timur Pocheptsov on 1/17/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import "NewsTableViewController.h"

@interface BulletinTableViewController : NewsTableViewController

@end

namespace CernAPP
{

NSString *BulletinTitleForWeek(NSArray *weekData);

}