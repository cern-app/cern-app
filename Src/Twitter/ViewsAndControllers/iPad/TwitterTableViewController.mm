#import <cassert>

#import "TwitterTableViewController.h"
#import "ECSlidingViewController.h"
#import "ApplicationErrors.h"
#import "Reachability.h"
#import "TweetCell.h"

@implementation TwitterTableViewController {
   UITableView *tableView;
   NSIndexPath *selected;
   
   MWFeedParser *parser;
   NSMutableArray *tweets;
   NSMutableArray *tmpData;
   
   Reachability *internetReach;
   BOOL viewDidAppear;
}

#pragma mark - Reachability.

//________________________________________________________________________________________
- (BOOL) hasConnection
{
   return internetReach && [internetReach currentReachabilityStatus] != CernAPP::NetworkStatus::notReachable;
}

#pragma mark - Lifecycle.

@synthesize spinner, noConnectionHUD;

//________________________________________________________________________________________
- (id) initWithCoder : (NSCoder *) aDecoder
{
   if (self = [super initWithCoder : aDecoder]) {
      parser = nil;
      internetReach = [Reachability reachabilityForInternetConnection];
   }
   
   return self;
}

#pragma mark - Other methods.

//________________________________________________________________________________________
- (void) setFeedURL : (NSString *) urlString
{
   assert(urlString != nil && "setFeedURL:, parameter 'urlString' is nil");

   if (NSURL * const url = [NSURL URLWithString:urlString]) {
      parser = [[MWFeedParser alloc] initWithFeedURL : url];
      parser.delegate = self;
      parser.connectionType = ConnectionTypeAsynchronously;
   } else {
      NSLog(@"setFeedURL:, error: bad url %@", urlString);
      parser = nil;
   }
}

//________________________________________________________________________________________
- (void) refresh
{
   if (!parser) {
      NSLog(@"refresh, error: parser is not initialized");
      return;
   }
   
   assert(parser.isParsing == NO && "refresh, parser is still parsing");
   
   [noConnectionHUD hide : YES];
   self.navigationItem.rightBarButtonItem.enabled = NO;
   
   CernAPP::ShowSpinner(self);
   
   //TODO: [self cancellAllImageDownloaders];
   
   tmpData = [[NSMutableArray alloc] init];
   [parser parse];
}

#pragma mark - viewDid/Will/Does/Never.

//________________________________________________________________________________________
- (void) viewDidLoad
{
   [super viewDidLoad];

	// Do any additional setup after loading the view, typically from a nib.
   tableView = [[UITableView alloc] initWithFrame : CGRect() style : UITableViewStylePlain];
   tableView.delegate = self;
   tableView.dataSource = self;
   tableView.backgroundColor = [UIColor lightGrayColor];

   [self.view addSubview : tableView];
   
   tableView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
                                UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
                                UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
   tableView.separatorColor = [UIColor clearColor];
   
   [tableView registerClass : [TweetCell class] forCellReuseIdentifier : @"TweetCell"];
   
   CernAPP::AddSpinner(self);
   CernAPP::HideSpinner(self);
}

//________________________________________________________________________________________
- (void) viewWillAppear : (BOOL) animated
{
   [super viewWillAppear : animated];
   CGRect frame = self.view.frame;
   frame.origin = CGPoint();
   tableView.frame = frame;
}

//________________________________________________________________________________________
- (void) viewDidAppear : (BOOL) animated
{
   [super viewDidAppear : animated];
   if (!viewDidAppear) {
      viewDidAppear = YES;
      [self refresh];
   }
}

//________________________________________________________________________________________
- (void) didReceiveMemoryWarning
{
   [super didReceiveMemoryWarning];
   // Dispose of any resources that can be recreated.
}

#pragma mark - UITableViewDataSource.

//________________________________________________________________________________________
- (NSInteger) numberOfSectionsInTableView : (UITableView *) tableView
{
   if (!tweets.count)
      return 0;
   
   return 1;
}

//________________________________________________________________________________________
- (NSInteger) tableView : (UITableView *) tableView numberOfRowsInSection : (NSInteger)section
{
   return tweets.count;
}

//________________________________________________________________________________________
- (UITableViewCell *) tableView : (UITableView *) aTableView cellForRowAtIndexPath : (NSIndexPath *)indexPath
{
   TweetCell * const cell = (TweetCell *)[tableView dequeueReusableCellWithIdentifier : @"TweetCell" forIndexPath : indexPath];
   UIView *bgColorView = [[UIView alloc] init];
   [bgColorView setBackgroundColor : [UIColor clearColor]];
   [cell setSelectedBackgroundView : bgColorView];
   
   [cell setCellFrame : cell.frame];

   return cell;
}


//________________________________________________________________________________________
- (CGFloat) tableView : (UITableView *) tableView heightForRowAtIndexPath : (NSIndexPath *) indexPath
{
   if (selected && [selected compare : indexPath] == NSOrderedSame)
      return [TweetCell expandedHeight];

   return [TweetCell collapsedHeight];
}

#pragma mark - UITableView delegate.

//________________________________________________________________________________________
- (void) tableView : (UITableView *) aTableView didSelectRowAtIndexPath : (NSIndexPath *) indexPath
{
   //[tableView deselectRowAtIndexPath:indexPath animated : NO];
   if (selected && [selected compare : indexPath] == NSOrderedSame)
      selected = nil;
   else
      selected = indexPath;

   [tableView beginUpdates];
   [tableView endUpdates];
}

#pragma mark - MWFeedParser delegate.

//________________________________________________________________________________________
- (void) feedParser : (MWFeedParser *) feedParser didParseFeedItem : (MWFeedItem *) item
{
   assert(feedParser != nil && "feedParser:didParseFeedItem:, parameter 'feedParser' is nil");
   assert(item != nil && "feedParser:didParseFeedItem:, parameter 'item' is nil");
   assert(tmpData != nil && "feedParser:didParseFeedItem:, tmpData is nil");

   [tmpData addObject : item];
}


//________________________________________________________________________________________
- (void) feedParser : (MWFeedParser *) feedParser didFailWithError : (NSError *) error
{
#pragma unused(error)

   assert(feedParser != nil && "feedParser:didFailWithError:, parameter 'feedParser' is nil");

   CernAPP::HideSpinner(self);
   self.navigationItem.rightBarButtonItem.enabled = YES;

   //Here, depending on the fact if we have data or not, we either show a HUD or an alert.
   if (!tweets.count)//Also true if tweets is nil.
      CernAPP::ShowErrorHUD(self, @"No network");
   else
      CernAPP::ShowErrorAlert(@"Please, check network connection!", @"Close");
}

//________________________________________________________________________________________
- (void) feedParserDidFinish : (MWFeedParser *) feedParser
{
   assert(feedParser != nil && "feedParserDidFinish:, parameter 'feedParser' is nil");
   
   tweets = tmpData;
   tmpData = nil;
   
   CernAPP::HideSpinner(self);
   self.navigationItem.rightBarButtonItem.enabled = YES;
   
   selected = nil;
   [tableView reloadData];
}

#pragma mark - ImageDownloader delegate.

//________________________________________________________________________________________
- (void) imageDidLoad : (NSIndexPath *) indexPath
{
#pragma unsued(indexPath)
}

//________________________________________________________________________________________
- (void) imageDownloadFailed : (NSIndexPath *) indexPath
{
#pragma unused(indexPath)
}

#pragma mark - ConnectionController.

//________________________________________________________________________________________
- (void) cancelAnyConnections
{
   //This method is called before the controller/view are removed.
   if (parser.isParsing)
      [parser stopParsing];
   
   parser = nil;
}

#pragma mark - UI

//________________________________________________________________________________________
- (IBAction) revealMenu : (id) sender
{
#pragma unused(sender)
   [self.slidingViewController anchorTopViewTo : ECRight];
}

//________________________________________________________________________________________
- (IBAction) refresh : (id) sender
{
#pragma unused(sender)
   assert(parser.isParsing == NO && "refresh:, parser is still parsing");
   
   if (![self hasConnection])
      CernAPP::ShowErrorAlert(@"Please, check netword!", @"Close");
   else
      [self refresh];
}

@end
