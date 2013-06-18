//Author: Timur Pocheptsov.
//Developed for CERN app.

//This is a code for a table view controller, which shows an author, a title, and a date for
//an every news item.
//It can be used ONLY for iPhone/iPod touch device, for iPad we'll have a different approach.

#import <Availability.h>

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
- (BOOL) hasConnection;

- (void) reloadPage;
- (void) reloadPageFromRefreshControl;
//
- (void) startFeedParsing;
//
@property (nonatomic, copy) NSString *feedStoreID;
//
- (IBAction) revealMenu : (id) sender;
//
- (void) hideActivityIndicators;
- (void) cancelAllImageDownloaders;
- (void) showErrorHUD;

@end

namespace CernAPP {

NSString *FirstImageURLFromHTMLString(NSString *htmlString);

}
