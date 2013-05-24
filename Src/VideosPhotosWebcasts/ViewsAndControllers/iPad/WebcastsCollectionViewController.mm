//
//  WebcastsViewController.m
//  CERN
//
//  Created by Timur Pocheptsov on 5/24/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import "WebcastsCollectionViewController.h"
#import "ECSlidingViewController.h"

//________________________________________________________________________________________
@implementation WebcastsCollectionViewController

- (id) initWithCoder : (NSCoder *) aDecoder
{
   if (self = [super initWithCoder : aDecoder]) {
   
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
