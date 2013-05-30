#import <UIKit/UIKit.h>

@class TwitterTableViewController;
@class MWFeedItem;

@interface TweetCell : UITableViewCell

+ (CGFloat) collapsedHeight;
+ (CGFloat) expandedHeight;
+ (CGFloat) expandedHeightWithImage;

@property (nonatomic, readonly) BOOL cellExpanded;
@property (nonatomic, weak) TwitterTableViewController *controller;

- (void) layoutSubviews;
- (void) setCellData : (MWFeedItem *) data forTweet : (NSString *) tweetName;

@end
