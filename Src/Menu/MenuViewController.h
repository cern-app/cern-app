//This code is based on a code sample by Michael Enriquez (EdgeCase).
//Code was further developed/modified (and probably broken) by Timur Pocheptsov
//for CERN.app - to load our own menu we need.

#import <UIKit/UIKit.h>

@interface MenuViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic) __weak IBOutlet UITableView *tableView;

@end