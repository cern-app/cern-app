#import <UIKit/UIKit.h>

@class MWFeedItem;

@interface TweetCell : UITableViewCell

+ (CGFloat) collapsedHeight;
+ (CGFloat) expandedHeight;
+ (CGFloat) expandedHeightWithImage;

- (void) layoutSubviews;
- (void) setCellData : (MWFeedItem *) data;

@end
