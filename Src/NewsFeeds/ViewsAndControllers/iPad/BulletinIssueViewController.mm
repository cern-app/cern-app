#import <cassert>

#import "BulletinIssueViewController.h"

@interface NewsFeedViewController(Private)
- (void) cancelAllImageDownloaders;
@end

@implementation BulletinIssueViewController

#pragma mark - Lifecycle.

//________________________________________________________________________________________
- (id) initWithCoder : (NSCoder *) aDecoder
{
   return self = [super initWithCoder : aDecoder];
}

//________________________________________________________________________________________
- (void) dealloc
{
   [self cancelAllImageDownloaders];
}

#pragma mark - Overriders for UIViewController.

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
   [super viewWillAppear : animated];
   
   self.navigationItem.rightBarButtonItem = nil;
}

#pragma mark - Aux.

//________________________________________________________________________________________
- (void) setData : (NSArray *) data
{
   dataItems = [data mutableCopy];
}

#pragma mark - PageController.

//________________________________________________________________________________________
- (void) refresh
{
   [self layoutPages : YES];
   [self layoutFlipView];
   [self layoutPanRegion];
   [self loadVisiblePageData];
   
   if (nPages > 1)
      [self showRightFlipHint];
   else
      [self hideFlipHint];
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
