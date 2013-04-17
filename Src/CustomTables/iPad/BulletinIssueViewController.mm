#import <cassert>

#import "BulletinIssueViewController.h"

@implementation BulletinIssueViewController

//________________________________________________________________________________________
- (id) initWithCoder : (NSCoder *) aDecoder
{
   return self = [super initWithCoder : aDecoder];
}

//________________________________________________________________________________________
- (void) viewDidLoad
{
   //By this point data should be set by the bulletin feed view controller.
   assert(dataItems != nil && "viewDidLoad, dataItems is nil");

   [super viewDidLoad];
}

//________________________________________________________________________________________
- (void) viewWillAppear : (BOOL) animated
{
   //TODO: find a better ("idiomatic") solution for this problem.
   [super viewWillAppear : animated];
   
   self.navigationItem.rightBarButtonItem = nil;
}

#pragma mark - PageController.

//________________________________________________________________________________________
- (void) reloadPage
{
   //Noop. We do not have 'refresh' at this level.
}

//________________________________________________________________________________________
- (void) reloadPageFromRefreshControl
{
   //Noop. We do not have 'refresh' at this level.
}

#pragma mark - Overriders for NewsFeedViewController.

//________________________________________________________________________________________
- (void) initTilesFromCache
{
   assert(dataItems != nil && "initTilesFromCache, dataItems is nil");
   [self setPagesData];
}

@end
