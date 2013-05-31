#import <UIKit/UIKit.h>

#import "ConnectionController.h"
#import "HUDRefreshProtocol.h"
#import "ImageDownloader.h"
#import "MWFeedParser.h"

@class MBProgressHUD;
@class MWFeedItem;

@interface TwitterTableViewController : UIViewController<UITableViewDelegate, UITableViewDataSource,
                                                         ConnectionController, MWFeedParserDelegate,
                                                         ImageDownloaderDelegate, HUDRefreshProtocol>

- (void) setFeedURL : (NSString *) urlString;
- (void) cellAnimationFinished;

@property (nonatomic) UIActivityIndicatorView *spinner;
@property (nonatomic) MBProgressHUD *noConnectionHUD;

@end
