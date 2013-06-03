#import <cassert>

#import <Accounts/Accounts.h>
#import <Twitter/TWRequest.h>

#import "ArticleDetailViewController.h"
#import "TwitterTableViewController.h"
#import "ECSlidingViewController.h"
#import "StoryboardIdentifiers.h"
#import "ApplicationErrors.h"
#import "TwitterTableView.h"
#import "Reachability.h"
#import "TweetCell.h"

@protocol TwitterOperation<NSObject>
@required

- (void) executeOperation;

@end

@interface RetweetOperation : NSObject<TwitterOperation>

@property (nonatomic, strong) MWFeedItem *tweet;
@property (nonatomic, strong) ACAccount *account;

@end

@implementation RetweetOperation

@synthesize tweet, account;

//________________________________________________________________________________________
- (void) executeOperation
{
   assert(tweet != nil && "executeOperation, tweet is nil");
   assert(account != nil && "executeOperation, account is nil");
   
   //Retweet using Twitter API.
}

@end

@implementation TwitterTableViewController {
   TwitterTableView *tableView;
   NSIndexPath *selected;
   
   MWFeedParser *parser;
   NSMutableArray *tweets;
   NSMutableArray *tmpData;
   
   Reachability *internetReach;
   BOOL viewDidAppear;
   
   NSString *tweetName;
   
   BOOL selectingAccount;
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
      
      selectingAccount = NO;
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

//________________________________________________________________________________________
- (BOOL) tableView : (UITableView *)tableView shouldHighlightRowAtIndexPath : (NSIndexPath *) indexPath
{
   return !selectingAccount;
}

#pragma mark - MWFeedParser delegate.

//________________________________________________________________________________________
- (void)feedParser : (MWFeedParser *) feedParser didParseFeedInfo : (MWFeedInfo *) info
{
   assert(feedParser != nil && "feedParser:didParseFeedInfo:, parameter 'feedParser' is nil");
   assert(info != nil && "feedParser:didParseFeedInfo:, parameter 'info' is nil");
   
   if (info.title.length) {
      const NSRange range = [info.title rangeOfString : @"/"];
      if (range.location != NSNotFound && range.location + 1 < info.title.length)
         tweetName = [[info.title substringFromIndex:range.location + 1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
      else
         tweetName = info.title;
   } else
      tweetName = @"";
}

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
   /*
   NSLog(@"<<<<< Feed's items:");
   for (MWFeedItem *item in tmpData) {
      NSLog(@"title: %@", item.title);
      NSLog(@"content: %@", item.content);
      NSLog(@"date: %@", item.date);
      NSLog(@"link: %@", item.link);
      NSLog(@"summary: %@", item.summary);
   }
   NSLog(@"End of feed>>>>>");
   */
   tmpData = nil;
   
   CernAPP::HideSpinner(self);
   self.navigationItem.rightBarButtonItem.enabled = YES;
   
   selected = nil;
   [tableView reloadData];
}

#pragma mark - UIWebViewDelegate.

///*
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
//*/

#pragma mark - ConnectionController.

//________________________________________________________________________________________
- (void) cancelAnyConnections
{
   //This method is called before the controller/view are removed.
   if (parser.isParsing)
      [parser stopParsing];
   
   parser = nil;
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
   assert(parser.isParsing == NO && "refresh:, parser is still parsing");
   
   if (![self hasConnection])
      CernAPP::ShowErrorAlert(@"Please, check netword!", @"Close");
   else
      [self refresh];
}

@end
