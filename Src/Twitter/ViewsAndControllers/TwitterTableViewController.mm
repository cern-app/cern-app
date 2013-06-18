#import <cassert>

#import "ArticleDetailViewController.h"
#import "TwitterTableViewController.h"
#import "ECSlidingViewController.h"
#import "StoryboardIdentifiers.h"
#import "ApplicationErrors.h"
#import "TwitterTableView.h"
#import "Reachability.h"
#import "TwitterAPI.h"
#import "TweetCell.h"
#import "GCOAuth.h"

@implementation TwitterTableViewController {
   TwitterTableView *tableView;

   NSIndexPath *selected;
   NSMutableArray *tweets;

   Reachability *internetReach;

   BOOL viewDidAppear;
   
   NSString *tweetName;
   NSURLConnection *urlConnection;
   NSMutableData *asyncData;
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
      tweetName = nil;
      internetReach = [Reachability reachabilityForInternetConnection];
   }
   
   return self;
}

#pragma mark - viewDid/Will/Does/Never.

//________________________________________________________________________________________
- (void) viewDidLoad
{
   [super viewDidLoad];

	// Do any additional setup after loading the view, typically from a nib.
   self.view.backgroundColor = [UIColor lightGrayColor];
   
   tableView = [[TwitterTableView alloc] initWithFrame : CGRect() style : UITableViewStylePlain];
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

#pragma mark - Refresh logic.

//________________________________________________________________________________________
- (void) setTwitterUserName : (NSString *) name
{
   assert(name != nil && "setTwitterUserName:, parameter 'name' is nil");

   tweetName = name;
}

//________________________________________________________________________________________
- (void) getUserTimeline
{
   assert(urlConnection == nil && "getUserTimeline, connection is still active");
   assert(tweetName != nil && "getUserTimeline, tweetName is nil");
   
   namespace TwitterAPI = CernAPP::TwitterAPI;
   
   NSURLRequest * const xauth = [GCOAuth URLRequestForPath : @"user_timeline.json"
                                 GETParameters : [NSDictionary dictionaryWithObjectsAndKeys : tweetName, @"screen_name", nil]
                                 scheme : @"https" host : @"api.twitter.com/1.1/statuses/"
                                 consumerKey : TwitterAPI::ConsumerKey() consumerSecret : TwitterAPI::ConsumerSecret()
                                 accessToken : TwitterAPI::OauthToken() tokenSecret : TwitterAPI::OauthTokenSecret()];
   if (xauth) {
      asyncData = [[NSMutableData alloc] init];// Create data
      urlConnection = [[NSURLConnection alloc] initWithRequest : xauth delegate : self];
   }
   
   if (!xauth || !urlConnection) {
      //Here, depending on the fact if we have data or not, we either show a HUD or an alert.
      //TODO: Error messages are not actually good, it's not clear if it's a network problem or what.

      asyncData = nil;
      CernAPP::HideSpinner(self);
      if (!tweets.count)//Also true if tweets is nil.
         CernAPP::ShowErrorHUD(self, @"Twitter API problem");
      else
         CernAPP::ShowErrorAlert(@"Twitter API problem", @"Close");
   }
}

//________________________________________________________________________________________
- (void) refresh
{
   assert(urlConnection == nil && "refresh, connection is still active");
   
   [noConnectionHUD hide : YES];
   self.navigationItem.rightBarButtonItem.enabled = NO;
   
   CernAPP::ShowSpinner(self);
   
   //TODO: [self cancellAllImageDownloaders];
   [self getUserTimeline];
}

#pragma mark - NSURLConnectionDelegate.

/*
//________________________________________________________________________________________
- (void) connection : (NSURLConnection *) connection didReceiveResponse : (NSURLResponse *) response
{
#pragma unused(connection, response)
   assert(connection == urlConnection && "connection:didReceiveRespone:, unknown connection");
   assert(asyncData != nil && "connection:didReceiveResponse:, asyncData is nil");

	[asyncData setLength : 0];
}
*/

//________________________________________________________________________________________
- (void) connection : (NSURLConnection *) connection didReceiveData : (NSData *) data
{
#pragma unused(connection)

   assert(connection == urlConnection && "connection:didReceiveData:, data from unknown connection");//:)
   assert(asyncData != nil && "connection:didReceiveData:, asyncData is nil");
   
	[asyncData appendData : data];
}

//________________________________________________________________________________________
- (void) connection : (NSURLConnection *) connection didFailWithError : (NSError *) error
{
#pragma unused(connection, error)

   assert(connection == urlConnection && "connection:didFailWithError:, unknown connection");
   
   [urlConnection cancel];
   urlConnection = nil;
   asyncData = nil;
   //
   if (!tweets.count)//Also true if tweets is nil.
      CernAPP::ShowErrorHUD(self, @"No network");
   else
      CernAPP::ShowErrorAlert(@"Please, check network connection", @"Close");
}

//________________________________________________________________________________________
- (void) connectionDidFinishLoading : (NSURLConnection *) connection
{
#pragma unused(connection)

   //Now we have a reply from the Twitter and can fill the table (if we have any data).
   assert(connection == urlConnection && "connectionDidFinishLoading:, unknown connection");

   //TODO: convert asyncData into tweet items.
   urlConnection = nil;
   asyncData = nil;
   
   CernAPP::HideSpinner(self);
   self.navigationItem.rightBarButtonItem.enabled = YES;
   
   selected = nil;
   [tableView reloadData];
}

//________________________________________________________________________________________
- (NSCachedURLResponse *) connection : (NSURLConnection *) connection willCacheResponse : (NSCachedURLResponse *) cachedResponse
{
	return nil; //Don't cache.
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
- (UITableViewCell *) tableView : (UITableView *) aTableView cellForRowAtIndexPath : (NSIndexPath *) indexPath
{
#pragma unused(aTableView)

   assert(indexPath != nil && "tableView:cellForRowAtIndexPath:, parameter 'indexPath' is nil");

   TweetCell * const cell = (TweetCell *)[tableView dequeueReusableCellWithIdentifier : @"TweetCell" forIndexPath : indexPath];
   cell.controller = self;
   UIView *bgColorView = [[UIView alloc] init];
   [bgColorView setBackgroundColor : [UIColor clearColor]];
   [cell setSelectedBackgroundView : bgColorView];

   assert(indexPath.row >= 0 && indexPath.row < tweets.count &&
          "tableView:cellForRowAtIndexPath:, row index is out of bounds");
   [cell setCellData : (MWFeedItem *)tweets[indexPath.row] forTweet : tweetName ? tweetName : @""];
   
   [cell layoutSubviews];

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
   [tableView deselectRowAtIndexPath:indexPath animated : NO];
   tableView.animatingSelection = YES;
   
   //1. Unselect the previous selected cell if any.
   if (selected) {
      NSArray * const cells = [tableView visibleCells];
      for (TweetCell *cell in cells) {
         NSIndexPath * const cellPath = [tableView indexPathForCell : cell];
         if (cellPath && [cellPath compare : selected] == NSOrderedSame) {
            [cell removeWebView];
            break;
         }
      }
   }
   
   //2. Now select the new one or deselect at all, if the same cell was selected again.
   selected = selected && [indexPath compare : selected] == NSOrderedSame ? nil : indexPath;

   [tableView beginUpdates];
   [tableView endUpdates];

}

#pragma mark - UIWebViewDelegate.

//________________________________________________________________________________________
- (BOOL) webView : (UIWebView *) webView shouldStartLoadWithRequest : (NSURLRequest *) request navigationType : (UIWebViewNavigationType) navigationType
{
   if (navigationType == UIWebViewNavigationTypeLinkClicked) {
      ArticleDetailViewController * const viewController = [self.storyboard instantiateViewControllerWithIdentifier : CernAPP::ArticleDetailViewControllerID];
      [viewController setLink : request.URL.absoluteString title : @""];
      viewController.navigationItem.title = @"";
      viewController.canUseReadability = NO;
      [self.navigationController pushViewController : viewController animated : YES];

      return NO;
   }

   return YES;
}

#pragma mark - ConnectionController.

//________________________________________________________________________________________
- (void) cancelAnyConnections
{
   //This method is called before the controller/view are removed.
   if (urlConnection)
      [urlConnection cancel];
   
   urlConnection = nil;
}

#pragma mark - Special tricks to work with web-views inside cells.

//________________________________________________________________________________________
- (void) cellAnimationFinished
{
   if (selected) {
      NSArray * const cells = [tableView visibleCells];
      for (TweetCell * cell in cells) {
         NSIndexPath * const indexPath = [tableView indexPathForCell : cell];
         if (indexPath && [indexPath compare : selected] == NSOrderedSame) {
            [cell addWebView : self];
            const CGRect frame = CGRectMake(cell.frame.origin.x, cell.frame.origin.y,
                                            cell.frame.size.width, [TweetCell expandedHeight]);
            [tableView scrollRectToVisible : frame animated : YES];

            break;
         }
      }
   }
}

//________________________________________________________________________________________
- (void) scrollViewWillBeginDragging : (UIScrollView *) scrollView
{
#pragma unused(scrollView)

   if (selected) {
      NSArray * const cells = [tableView visibleCells];
      for (TweetCell *cell in cells) {
         NSIndexPath * const indexPath = [tableView indexPathForCell : cell];
         if (indexPath && [indexPath compare:selected] == NSOrderedSame) {
            [cell removeWebView];
            break;
         }
      }

      selected = nil;
      [tableView beginUpdates];
      [tableView endUpdates];
   }
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
   assert(urlConnection == nil && "refresh:, parser is still parsing");

   if (![self hasConnection])
      CernAPP::ShowErrorAlert(@"Please, check netword!", @"Close");
   else
      [self refresh];
}

@end
