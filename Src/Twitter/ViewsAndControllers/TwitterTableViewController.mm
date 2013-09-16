#import <cassert>

#import "ArticleDetailViewController.h"
#import "TwitterTableViewController.h"
#import "ECSlidingViewController.h"
#import "StoryboardIdentifiers.h"
#import "ApplicationErrors.h"
#import "TwitterTableView.h"
#import "NSString+HTML.h"
#import "Reachability.h"
#import "DeviceCheck.h"
#import "TwitterAPI.h"
#import "TweetCell.h"
#import "GCOAuth.h"

@implementation TwitterTableViewController {
   //TwitterTableView *tableView;

   NSIndexPath *selected;
   NSMutableArray *tweets;

   Reachability *internetReach;

   BOOL viewDidAppear;
   
   NSString *tweetName;
   NSURLConnection *urlConnection;
   NSMutableData *asyncData;
   
   NSDateFormatter *dateFormatter;
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
      dateFormatter = [[NSDateFormatter alloc] init];
      //From https://dev.twitter.com/docs/platform-objects/tweets:

      //UTC time when this Tweet was created. Example:
      //"created_at":"Wed Aug 27 13:08:45 +0000 2008"
      [dateFormatter setDateFormat : @"EEE LLL d HH:mm:ss Z yyyy"];
   }
   
   return self;
}

#pragma mark - viewDid/Will/Does/Never.

//________________________________________________________________________________________
- (void) viewDidLoad
{
   [super viewDidLoad];

	// Do any additional setup after loading the view, typically from a nib.
   if (CernAPP::SystemVersionGreaterThanOrEqualTo(@"7.0"))
      self.view.backgroundColor = [UIColor colorWithRed : 0.95f green : 0.95f blue : 0.95f alpha : 1.f];
   else
      self.view.backgroundColor = [UIColor lightGrayColor];
   
   self.tableView.separatorColor = [UIColor clearColor];
   [self.tableView registerClass : [TweetCell class] forCellReuseIdentifier : [TweetCell reuseIdentifier]];
   
   self.refreshControl = [[UIRefreshControl alloc] init];
   [self.refreshControl addTarget : self action : @selector(refresh:) forControlEvents : UIControlEventValueChanged];
   
   CernAPP::AddSpinner(self);
   CernAPP::HideSpinner(self);
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
      [self.refreshControl endRefreshing];

      if (!tweets.count)//Also true if tweets is nil.
         CernAPP::ShowErrorHUD(self, @"Twitter API problem");
      else {
         if (self.navigationController.topViewController == self)
            CernAPP::ShowErrorAlert(@"Twitter API problem", @"Close");
      }
   }
}

//________________________________________________________________________________________
- (void) refresh
{
   assert(urlConnection == nil && "refresh, connection is still active");
   
   [noConnectionHUD hide : YES];
   
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
   
   CernAPP::HideSpinner(self);
   [self.refreshControl endRefreshing];
   
   [urlConnection cancel];
   urlConnection = nil;
   asyncData = nil;
   //
   if (!tweets.count)//Also true if tweets is nil.
      CernAPP::ShowErrorHUD(self, @"Network error, pull to refresh");
   else {
      if (self.navigationController.topViewController == self)
         CernAPP::ShowErrorAlert(@"Please, check network connection", @"Close");
   }
}

//________________________________________________________________________________________
- (void) connectionDidFinishLoading : (NSURLConnection *) connection
{
#pragma unused(connection)

   //Now we have a reply from the Twitter and can fill the table (if we have any data).
   assert(connection == urlConnection && "connectionDidFinishLoading:, unknown connection");

   CernAPP::HideSpinner(self);
   [self.refreshControl endRefreshing];
   
   [self readTweetsFromJSON];
   [self.tableView reloadData];

   urlConnection = nil;
   asyncData = nil;
   selected = nil;
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

   TweetCell * const cell = (TweetCell *)[self.tableView dequeueReusableCellWithIdentifier : @"TweetCell" forIndexPath : indexPath];
   cell.controller = self;

   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
      UIView *bgColorView = [[UIView alloc] init];
      [bgColorView setBackgroundColor : [UIColor clearColor]];
      [cell setSelectedBackgroundView : bgColorView];
   } else
      cell.selectionStyle = UITableViewCellSelectionStyleGray;

   assert(indexPath.row >= 0 && indexPath.row < tweets.count &&
          "tableView:cellForRowAtIndexPath:, row index is out of bounds");
   [cell setCellData : (NSDictionary *)tweets[indexPath.row] forTweet : tweetName ? tweetName : @""];
   
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
   [self.tableView deselectRowAtIndexPath : indexPath animated : NO];
   
   
   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
      //Open tweet in with an ArticleDetailedViewController.
      assert(indexPath.row >= 0 && indexPath.row < tweets.count &&
             "tableView:didSelectRowAtIndexPath:, row index is out of bounds");
      NSDictionary * const dict = (NSDictionary *)tweets[indexPath.row];
      assert(dict[@"link_str"] != nil && "tableView:didSelectRowAtIndexPath:, no link found for this tweet");
      
      ArticleDetailViewController * const viewController = [self.storyboard instantiateViewControllerWithIdentifier : CernAPP::ArticleDetailViewControllerID];
      [viewController setLink : (NSString *)dict[@"link_str"] title : @""];
      viewController.navigationItem.title = @"";
      viewController.canUseReadability = NO;
      [self.navigationController pushViewController : viewController animated : YES];
   } else {   
      assert([self.tableView isKindOfClass : [TwitterTableView class]] &&
             "tableView:didSelectRowAtIndexPath:, self.tableView must be of a TwitterTableView type");
      
      ((TwitterTableView *)self.tableView).animatingSelection = YES;

      //1. Unselect the previous selected cell if any.
      if (selected) {
         NSArray * const cells = [self.tableView visibleCells];
         for (TweetCell *cell in cells) {
            NSIndexPath * const cellPath = [self.tableView indexPathForCell : cell];
            if (cellPath && [cellPath compare : selected] == NSOrderedSame) {
               [cell removeWebView];
               break;
            }
         }
      }
      
      //2. Now select the new one or deselect at all, if the same cell was selected again.
      selected = selected && [indexPath compare : selected] == NSOrderedSame ? nil : indexPath;

      [self.tableView beginUpdates];
      [self.tableView endUpdates];
   }
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
      NSArray * const cells = [self.tableView visibleCells];
      for (TweetCell * cell in cells) {
         NSIndexPath * const indexPath = [self.tableView indexPathForCell : cell];
         if (indexPath && [indexPath compare : selected] == NSOrderedSame) {
            [cell addWebView : self];
            const CGRect frame = CGRectMake(cell.frame.origin.x, cell.frame.origin.y,
                                            cell.frame.size.width, [TweetCell expandedHeight]);
            [self.tableView scrollRectToVisible : frame animated : YES];
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
      NSArray * const cells = [self.tableView visibleCells];
      for (TweetCell *cell in cells) {
         NSIndexPath * const indexPath = [self.tableView indexPathForCell : cell];
         if (indexPath && [indexPath compare:selected] == NSOrderedSame) {
            [cell removeWebView];
            break;
         }
      }

      selected = nil;
      [self.tableView beginUpdates];
      [self.tableView endUpdates];
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
- (void) refresh : (id) sender
{
#pragma unused(sender)
   assert([self.tableView isKindOfClass : [TwitterTableView class]] &&
          "tableView:didSelectRowAtIndexPath:, self.tableView must be of a TwitterTableView type");

   if (urlConnection != nil || ((TwitterTableView *)self.tableView).animatingSelection) {
      [self.refreshControl endRefreshing];
      return;
   }

   if (![self hasConnection]) {
      CernAPP::ShowErrorAlert(@"Please, check network!", @"Close");
      [self.refreshControl endRefreshing];
      return;
   }

   [noConnectionHUD hide : YES];   
   //TODO: [self cancellAllImageDownloaders];
   [self getUserTimeline];

}

#pragma mark - interface rotation.

//________________________________________________________________________________________
- (BOOL) shouldAutorotate
{
   return UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPhone;
}

#pragma mark - Aux. methods.

//________________________________________________________________________________________
- (void) readTweetsFromJSON
{
   assert(asyncData != nil && "readTweetsFromJSON, asyncData is nil");
   
   NSError *err = nil;
   id jsonObject = [NSJSONSerialization JSONObjectWithData : asyncData options : NSJSONReadingAllowFragments error : &err];
   if (jsonObject && !err && [jsonObject isKindOfClass : [NSArray class]]) {
      NSArray * const tweetDicts = (NSArray *)jsonObject;
      NSMutableArray *newTweets = [[NSMutableArray alloc] init];
      for (id item in tweetDicts) {
         if ([item isKindOfClass : [NSDictionary class]]) {
            NSDictionary * const dict = (NSDictionary *)item;
            //Now, let's create a TweetItem, something like MWFeedItem,
            //but for a tweet.
            NSDate *date = nil;
            if ([dict[@"created_at"] isKindOfClass : [NSString class]])//false == either nil or has a wrong type
               date = [dateFormatter dateFromString:(NSString *)dict[@"created_at"]];
            if (!date)
               date = [NSDate date];
            NSString *text = nil;
            if (dict[@"text" ] && [dict[@"text"] isKindOfClass : [NSString class]])
               text = (NSString *)dict[@"text"];
            if (!text)
               text = @"";
            
            NSString *idStr = nil;
            if (dict[@"id_str"] && [dict[@"id_str"] isKindOfClass : [NSString class]])
               idStr = (NSString *)dict[@"id_str"];
            if (idStr.length) {
               NSString * const link = [NSString stringWithFormat : @"https://twitter.com/%@/statuses/%@", tweetName, idStr];
               NSURLRequest * const req = [NSURLRequest requestWithURL : [NSURL URLWithString : link]];
               if (req)
                  [newTweets addObject : @{@"created_at" : date, @"text" : text, @"link" : req, @"link_str" : link}];
            }
         }
      }
      
      tweets = newTweets;
   } //else - it's probably a dictionary with error message,
     //I do not show this to a user, since it's quite ... useless.
}

@end
