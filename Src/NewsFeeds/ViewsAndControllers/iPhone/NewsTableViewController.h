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
   NSArray *feedCache;//Controller's specific data to cache in DB.
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
- (BOOL) initFromAppCache;
- (BOOL) initFromDBCache;//To be overriden if feedCache

//Feed store ID must be set to some value before viewDidAppear called.
//This must be an unique identifier to save feed's data in a DB or/an app's cache.
//It's up to a user to verify that feedStoreID is unique.

//feedIDString is unique identifier: it's the name used for
//caching feed data.
@property (nonatomic) NSString *feedCacheID;
//feedApnID is an integer (unique) to remember
//the time view was update the last time.
//It's the same integer identifier as APN uses.
@property (nonatomic) NSUInteger feedApnID;
//
@end

namespace CernAPP {

NSString *FirstImageURLFromHTMLString(NSString *htmlString);

}
