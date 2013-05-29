#import <UIKit/UIKit.h>

@class MWFeedItem;

@interface TweetCell : UITableViewCell

+ (CGFloat) collapsedHeight;
+ (CGFloat) expandedHeight;
+ (CGFloat) expandedHeightWithImage;

@property (nonatomic, readonly) BOOL cellExpanded;

- (void) layoutSubviews;
- (void) setCellData : (MWFeedItem *) data forTweet : (NSString *) tweetName;

@end
