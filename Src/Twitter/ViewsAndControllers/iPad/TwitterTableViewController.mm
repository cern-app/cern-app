#import "TwitterTableViewController.h"
#import "ECSlidingViewController.h"
#import "TweetCell.h"

@implementation TwitterTableViewController {
   UITableView *tableView;
   NSIndexPath *selected;
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
}

//________________________________________________________________________________________
- (void) viewWillAppear:(BOOL)animated
{
   [super viewWillAppear : animated];
   CGRect frame = self.view.frame;
   frame.origin = CGPoint();
   tableView.frame = frame;
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
   return 1;
}

//________________________________________________________________________________________
- (NSInteger) tableView : (UITableView *) tableView numberOfRowsInSection : (NSInteger)section
{
   //TODO: implementation.
   //Just a test, not a real data.
   return 100;
}

//________________________________________________________________________________________
- (UITableViewCell *)tableView:(UITableView *)aTableView cellForRowAtIndexPath : (NSIndexPath *)indexPath
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

   //TODO: implementation.
}


//________________________________________________________________________________________
- (void) feedParser : (MWFeedParser *) feedParser didFailWithError : (NSError *) error
{
#pragma unused(error)

   assert(feedParser != nil && "feedParser:didFailWithError:, parameter 'feedParser' is nil");

   //TODO: implementation.
}

//________________________________________________________________________________________
- (void) feedParserDidFinish : (MWFeedParser *) feedParser
{
   assert(feedParser != nil && "feedParserDidFinish:, parameter 'feedParser' is nil");
   
   //TODO: implementation.
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
   //TODO: implementation.
}

@end
