//Author: Timur Pocheptsov.
//Developed for CERN app.

#import <UIKit/UIKit.h>

#import "ConnectionController.h"
#import "ThumbnailDownloader.h"
#import "FeedParserOperation.h"
#import "MBProgressHUD.h"

@interface NewsTableViewController : UITableViewController<UITableViewDataSource, UITableViewDelegate, FeedParserOperationDelegate,
                                                           ThumbnailDownloaderDelegate, ConnectionController>
{
@protected
   BOOL canUseCache;
   UIActivityIndicatorView *spinner;
   MBProgressHUD *noConnectionHUD;
   FeedParserOperation *parseOp;
}

- (void) setFeedURLString : (NSString *) urlString;
- (void) setFilters : (NSObject *) filters;
- (BOOL) hasConnection;

//
- (void) startFeedParsing;
//
@property (nonatomic, copy) NSString *feedStoreID;
//
@end

namespace CernAPP {

NSString *FirstImageURLFromHTMLString(NSString *htmlString);

}
