//
//  WebcastsViewController.m
//  CERN
//
//  Created by Timur Pocheptsov on 5/24/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <cassert>

#import "WebcastsCollectionViewController.h"
#import "ECSlidingViewController.h"

//________________________________________________________________________________________
@implementation WebcastsCollectionViewController {
   NSString *liveLink;
   NSString *upcomingLink;
   NSString *recentLink;
}

- (id) initWithCoder : (NSCoder *) aDecoder
{
   if (self = [super initWithCoder : aDecoder]) {
      liveLink = nil;
      upcomingLink = nil;
      recentLink = nil;
   }
   
   return self;
}

//________________________________________________________________________________________
- (void) viewDidLoad
{
   [super viewDidLoad];
	// Do any additional setup after loading the view.
}

//________________________________________________________________________________________
- (void) didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Other methods.

//________________________________________________________________________________________
- (void) setControllerData : (NSArray *) dataItems
{
   assert(dataItems != nil && "setControllerData:, parameter 'dataItems' is nil");
   //We have 3 segments, 3 views, we need 3 links.
   assert(dataItems.count == 3 && "setControllerData:, unexpected number of items");
   //
   for (id item in dataItems) {
      /*
      assert([item isKindOfClass : [NSDictionary class]] &&
             "setControllerData:, a data item has a wrong type");
      
      NSDictionary * const itemDict = (NSDictionary *)item;
      assert([itemDict[@"Category name"] isKindOfClass : [NSString class]] &&
             "setControllerData:, 'Category name' is not found or has a wrong type");
      
      NSString * const name = (NSString *)itemDict[@"Category name"];
      assert([itemDict[@"Url"] isKindOfClass : [NSString class]] &&
             "setControllerData:, 'Url' is not found or has a wrong type");*/
   }
}

#pragma mark - UI.

//________________________________________________________________________________________
- (IBAction) sectionSelected : (UISegmentedControl *) sender
{

}

//________________________________________________________________________________________
- (IBAction) revealMenu : (id) sender
{
#pragma unused(sender)
   [self.slidingViewController anchorTopViewTo : ECRight];
}

//________________________________________________________________________________________
- (IBAction) reload : (id) sender
{

}

@end
