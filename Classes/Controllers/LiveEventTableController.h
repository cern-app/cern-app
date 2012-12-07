#import <UIKit/UIKit.h>

#import "PageControllerProtocol.h"

@class LiveEventsProvider;

//Now we want to be able to have a table with different LIVE events in different cells.
//Each cell will have a name and image (small version of an original image) + (possibly) date.
//Images to be reused by EventDisplayViewController later (if they were loaded already,
//if not - they have to be loaded by EventDisplayViewController.
//Unfortunately, as experiments don't have uniform live event representation,
//this class have to know too much about concrete experiments and the way they
//display live events.

@interface LiveEventTableController : UITableViewController<NSURLConnectionDelegate, UITableViewDataSource, UITableViewDelegate, PageController>

//These are the keys to be used when setting table's data -
//array of dictionaries.
+ (NSString *) nameKey;
+ (NSString *) urlKey;

//Content provider and LiveEventTableController share the 'contents' array.
- (void) setTableContents : (NSArray *) contents experimentName : (NSString *) name;

- (void) refresh;

//PageController protocol.
- (void) reloadPage;
@property (nonatomic) BOOL pageLoaded;

@property (nonatomic) __weak LiveEventsProvider *provider;
@property (nonatomic) __weak UINavigationController *navController;

@end

