#import <UIKit/UIKit.h>

#import "AccountSelectorController.h"
#import "ConnectionController.h"
#import "HUDRefreshProtocol.h"
#import "ImageDownloader.h"
#import "MWFeedParser.h"

@class MBProgressHUD;
@class MWFeedItem;

@interface TwitterTableViewController : UIViewController<UITableViewDelegate, UITableViewDataSource,
                                                         ConnectionController, MWFeedParserDelegate,
                                                         ImageDownloaderDelegate, HUDRefreshProtocol,
                                                         AccountSelectorDelegate,
                                                         UIPopoverControllerDelegate>

- (void) setFeedURL : (NSString *) urlString;
- (void) reTweet : (MWFeedItem *) tweet;

@property (nonatomic) UIActivityIndicatorView *spinner;
@property (nonatomic) MBProgressHUD *noConnectionHUD;

@end
