#import <UIKit/UIKit.h>

#import "ConnectionController.h"
#import "HUDRefreshProtocol.h"

@class MBProgressHUD;

@interface TwitterTableViewController : UITableViewController<UITableViewDelegate, UITableViewDataSource,
                                                              NSURLConnectionDelegate, UIWebViewDelegate,
                                                              ConnectionController, HUDRefreshProtocol>

- (void) setTwitterUserName : (NSString *) name;
- (void) cellAnimationFinished;

@property (nonatomic) UIActivityIndicatorView *spinner;
@property (nonatomic) MBProgressHUD *noConnectionHUD;

@end
