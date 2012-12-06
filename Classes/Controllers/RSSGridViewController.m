//
//  RSSGridViewController.m
//  CERN App
//
//  Created by Eamon Ford on 8/9/12.
//  Copyright (c) 2012 CERN. All rights reserved.
//

#import "RSSGridViewController.h"
#import "MBProgressHUD.h"

@interface RSSGridViewController ()

@end

@implementation RSSGridViewController

- (id)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super initWithCoder:aDecoder]) {
        self.aggregator = [[RSSAggregator alloc] init];
        self.aggregator.delegate = self;
        self.gridView.separatorStyle = AQGridViewCellSeparatorStyleNone;
        self.gridView.backgroundColor = [UIColor whiteColor];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // When we call self.view this will reload the view after a didReceiveMemoryWarning.
    self.view.backgroundColor = [UIColor whiteColor];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        return YES;
    else
        return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)refresh
{
    if (self.aggregator.feeds.count) {
        [_noConnectionHUD hide:YES];
        [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        [self.aggregator refreshAllFeeds];
    }
}

#pragma mark - MBProgressHUDDelegate methods

- (void)hudWasTapped:(MBProgressHUD *)hud
{
    [self refresh];
}

#pragma mark - RSSAggregatorDelegate methods

- (void) allFeedsDidLoadForAggregator:(RSSAggregator *)aggregator
{
    [MBProgressHUD hideHUDForView:self.view animated:YES];
}

- (void)aggregator:(RSSAggregator *)aggregator didFailWithError:(NSError *)error
{
    [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
	_noConnectionHUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    
    _noConnectionHUD.delegate = self;
    _noConnectionHUD.mode = MBProgressHUDModeText;
    _noConnectionHUD.labelText = @"No internet connection";
    _noConnectionHUD.removeFromSuperViewOnHide = YES;

}

@end

////////////////////////
@implementation RSSTableViewController {
   MBProgressHUD *_noConnectionHUD;
}

//________________________________________________________________________________________
- (id) initWithCoder : (NSCoder *) aDecoder
{
   if (self = [super initWithCoder : aDecoder]) {
      self.aggregator = [[RSSAggregator alloc] init];
      self.aggregator.delegate = self;
   }

   return self;
}

//________________________________________________________________________________________
- (void) viewDidLoad
{
   [super viewDidLoad];
#ifdef __IPHONE_6_0
   self.refreshControl = [[UIRefreshControl alloc] init];
   [self.refreshControl addTarget : self action : @selector(refresh) forControlEvents : UIControlEventValueChanged];
#endif
   // When we call self.view this will reload the view after a didReceiveMemoryWarning.
   //self.view.backgroundColor = [UIColor whiteColor];
}

//________________________________________________________________________________________
- (void) viewDidUnload
{
   [super viewDidUnload];
   // Release any retained subviews of the main view.
}

//________________________________________________________________________________________
- (BOOL) shouldAutorotateToInterfaceOrientation : (UIInterfaceOrientation) interfaceOrientation
{
   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
      return YES;
   else
      return interfaceOrientation == UIInterfaceOrientationPortrait;
}

//________________________________________________________________________________________
- (void) refresh
{
   if (self.aggregator.feeds.count) {
      [_noConnectionHUD hide : YES];
      [MBProgressHUD showHUDAddedTo : self.view animated : YES];
      [self.aggregator refreshAllFeeds];
   }
}

#pragma mark - MBProgressHUDDelegate methods

//________________________________________________________________________________________
- (void) hudWasTapped : (MBProgressHUD *) hud
{
   [self refresh];
}

#pragma mark - RSSAggregatorDelegate methods

//________________________________________________________________________________________
- (void) allFeedsDidLoadForAggregator : (RSSAggregator *) aggregator
{
   [MBProgressHUD hideHUDForView : self.view animated : YES];
#ifdef __IPHONE_6_0
   [self.refreshControl endRefreshing];
#else
   [self stopLoading];
#endif
}

//________________________________________________________________________________________
- (void) aggregator : (RSSAggregator *) aggregator didFailWithError : (NSError *)error
{
   [MBProgressHUD hideAllHUDsForView : self.view animated:YES];
   _noConnectionHUD = [MBProgressHUD showHUDAddedTo : self.view animated : YES];
    
   _noConnectionHUD.delegate = self;
   _noConnectionHUD.mode = MBProgressHUDModeText;
   _noConnectionHUD.labelText = @"No internet connection";
   _noConnectionHUD.removeFromSuperViewOnHide = YES;
}

@end
