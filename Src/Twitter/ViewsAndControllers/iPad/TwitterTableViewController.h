#import <UIKit/UIKit.h>

#import "ConnectionController.h"
#import "ImageDownloader.h"
#import "MWFeedParser.h"

@interface TwitterTableViewController : UIViewController<UITableViewDelegate, UITableViewDataSource,
                                                         ConnectionController, MWFeedParserDelegate,
                                                         ImageDownloaderDelegate>

@end
