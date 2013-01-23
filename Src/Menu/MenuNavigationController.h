//
//MenuNavigationController - the parent controller for all other controllers,
//which can be loaded from the menu.
//

#import <UIKit/UIKit.h>

#import "ConnectionController.h"
#import "Experiments.h"

@interface MenuNavigationController : UINavigationController<ConnectionController>

@end
