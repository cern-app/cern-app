//
//  AccountSelectorController.m
//  CERN
//
//  Created by Timur Pocheptsov on 5/30/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <cassert>

#import <Accounts/Accounts.h>

#import "AccountSelectorController.h"

@implementation AccountSelectorController {
   NSArray *accounts;
}

@synthesize delegate;

//________________________________________________________________________________________
- (id) initWithStyle : (UITableViewStyle) style
{
   if (self = [super initWithStyle : style]) {
      // Custom initialization
   }

   return self;
}

//________________________________________________________________________________________
- (void) setData : (NSArray *) data
{
   assert(data != nil && "setData:, parameter 'data' is nil");
   assert(data.count == 2 && "setData:, unexpected number of items found");
   assert([data[0] isKindOfClass : [NSArray class]] &&
          "setData:, the first element must be an array with accounts");
   accounts = [(NSArray *)data[0] copy];
}

#pragma mark - viewDid/Does/Will/Never.

//________________________________________________________________________________________
- (void) viewDidLoad
{
   [super viewDidLoad];
   
   [self.tableView registerClass : [UITableViewCell class] forCellReuseIdentifier:@"AccountCell"];
}

#pragma mark - Table view data source

//________________________________________________________________________________________
- (NSInteger) numberOfSectionsInTableView : (UITableView *) tableView
{
#pragma unused(tableView)
   assert(accounts.count != 0 && "numberOfSectionsInTableView:, no accounts info found");

   return 1;
}

//________________________________________________________________________________________
- (NSInteger) tableView : (UITableView *) tableView numberOfRowsInSection : (NSInteger) section
{
#pragma unused(tableView)

   assert(section == 0 && "tableView:numberOfRowsInSection:, section index is out of bounds");
   assert(accounts.count != 0 && "tableView:numberOfRowsInSection:, no accounts info found");
   return accounts.count;
}

//________________________________________________________________________________________
- (UITableViewCell *) tableView : (UITableView *) tableView cellForRowAtIndexPath : (NSIndexPath *) indexPath
{
#pragma unsued(tableView)

   assert(indexPath != nil && "tableView:cellForRowAtIndexPath:, parameter 'indexPath' is nil");

   UITableViewCell * const cell = [tableView dequeueReusableCellWithIdentifier:@"AccountCell" forIndexPath : indexPath];
   assert(cell != nil && "tableView:cellForRowAtIndexPath:, cell is nil");
   
   assert(indexPath.row >= 0 && indexPath.row < accounts.count &&
          "tableView:cellForRowAtIndexPath:, row index is out of bounds");
   ACAccount * const account = (ACAccount *)accounts[indexPath.row];
   cell.textLabel.text = account.username;
    
   return cell;
}

#pragma mark - Table view delegate

//________________________________________________________________________________________
- (void) tableView : (UITableView *) tableView didSelectRowAtIndexPath : (NSIndexPath *) indexPath
{
#pragma unused(tableView)
   
   assert(indexPath != nil && "tableView:didSelectRowAtIndexPath:, parameter 'indexPath' is nil");
   assert(indexPath.row >= 0 && indexPath.row < accounts.count &&
          "tableView:didSelectRowAtIndexPath:, row index is out of bounds");
   assert(delegate != nil && "tableView:didSelectRowAtIndexPath:, delegate is nil");
   
   [delegate accountSelected : (ACAccount *)accounts[indexPath.row]];
}

@end
