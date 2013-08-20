#import <UIKit/UIKit.h>

@class MenuItemsGroupView;
@class MenuItemView;

@interface MenuViewController : UIViewController<NSURLConnectionDelegate> {
   IBOutlet __weak UIScrollView *scrollView;
}

- (BOOL) itemViewWasSelected : (MenuItemView *) view;
- (void) groupViewWasTapped : (MenuItemsGroupView *) view;

- (void) checkPushNotifications;

@end
