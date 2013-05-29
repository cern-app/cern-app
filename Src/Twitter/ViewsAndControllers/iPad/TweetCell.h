#import <UIKit/UIKit.h>

@interface TweetCell : UITableViewCell

+ (CGFloat) collapsedHeight;
+ (CGFloat) expandedHeight;
+ (CGFloat) expandedHeightWithImage;

- (void) setCellFrame : (CGRect) frame;

@end
