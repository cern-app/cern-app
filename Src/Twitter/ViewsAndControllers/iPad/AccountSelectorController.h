//
//  AccountSelectorController.h
//  CERN
//
//  Created by Timur Pocheptsov on 5/30/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ACAccount;

@protocol AccountSelectorDelegate
@required

//- (void) account : (ACAccount *) account selectedForOperation : (id) operation;
- (void) accountSelected : (ACAccount *) account;

@end


@interface AccountSelectorController : UITableViewController

@property (nonatomic, weak) NSObject<AccountSelectorDelegate> *delegate;

- (void) setData : (NSArray *) data;

@end
