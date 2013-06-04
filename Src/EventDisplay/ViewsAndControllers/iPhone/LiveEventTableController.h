#import <UIKit/UIKit.h>

#import "ConnectionController.h"

@class LiveEventsProvider;

//Now we want to be able to have a table with different LIVE events in different cells.
//Each cell will have a name and an image (small version of an original image) + (possibly) date.
//Table always have some cells with names (this data is read from CERNLive.plist), even
//if there is no network. Images, sure, require a network connection to be downloaded.

@interface LiveEventTableController : UITableViewController<NSURLConnectionDelegate, UITableViewDataSource, UITableViewDelegate,
                                                            ConnectionController>

//These are the keys to be used when setting table's data -
//array of dictionaries.
+ (NSString *) nameKey;
+ (NSString *) urlKey;

//Content provider and LiveEventTableController share the 'contents' array.
- (void) setTableContents : (NSArray *) contents experimentName : (NSString *) name;
- (void) refresh;

- (void) reloadPage;
- (void) reloadPageFromRefreshControl;

@property (nonatomic) __weak LiveEventsProvider *provider;
@property (nonatomic) __weak UINavigationController *navController;

- (IBAction) revealMenu : (id) sender;

@end
