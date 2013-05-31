#import <UIKit/UIKit.h>

@class TwitterTableViewController;
@class MWFeedItem;

@interface TweetCell : UITableViewCell

+ (CGFloat) collapsedHeight;
+ (CGFloat) expandedHeight;

@property (nonatomic, readonly) BOOL cellExpanded;
@property (nonatomic, weak) TwitterTableViewController *controller;

- (void) layoutSubviews;
- (void) setCellData : (MWFeedItem *) data forTweet : (NSString *) tweetName;

- (void) addWebView;
- (void) removeWebView;

@end
