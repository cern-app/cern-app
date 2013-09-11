#import <UIKit/UIKit.h>

//
//APNHintView - simple view, yellow circle with a number inside
//(APN == Apple push notification, number == number of new items.
//

@interface APNHintView : UIView

//Count to show in a hint view, if > 99 - '!' will be
//shown instead.
@property (nonatomic) NSUInteger count;
@property (nonatomic, weak) id delegate;

@end
