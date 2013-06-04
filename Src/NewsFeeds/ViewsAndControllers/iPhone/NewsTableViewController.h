//Author: Timur Pocheptsov.
//Developed for CERN app.

//This is a code for a table view controller, which shows an author, a title, and a date for
//an every news item.
//It can be used ONLY for iPhone/iPod touch device, for iPad we'll have a different approach.

#import <Availability.h>

#import <UIKit/UIKit.h>

#import "ConnectionController.h"
#import "ImageDownloader.h"
#import "RSSAggregator.h"
#import "MBProgressHUD.h"

@interface NewsTableViewController : UITableViewController<UITableViewDataSource, UITableViewDelegate,
                                                           RSSAggregatorDelegate, ImageDownloaderDelegate,
                                                           ConnectionController>
{
@protected
   BOOL canUseCache;
   UIActivityIndicatorView *spinner;
   MBProgressHUD *noConnectionHUD;
}

+ (NSString *) firstImageURLFromHTMLString : (NSString *) htmlString;

- (void) reloadPage;
- (void) reloadPageFromRefreshControl;

@property (nonatomic, strong) RSSAggregator *aggregator;
@property (nonatomic, strong) NSMutableDictionary *imageDownloaders;
@property (nonatomic) NSUInteger nLoadedImages;
@property (nonatomic) BOOL isTwitterFeed;
//
@property (nonatomic, copy) NSString *feedStoreID;
//
- (IBAction) revealMenu : (id) sender;
//
- (void) cancelAllImageDownloaders;
- (void) showErrorHUD;

@end
