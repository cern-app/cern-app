#import <UIKit/UIKit.h>

@class TwitterTableViewController;

@interface TweetCell : UITableViewCell

+ (CGFloat) collapsedHeight;
+ (CGFloat) expandedHeight;

+ (NSString *) reuseIdentifier;

@property (nonatomic, readonly) BOOL cellExpanded;
@property (nonatomic, weak) TwitterTableViewController *controller;

- (void) layoutSubviews;
- (void) setCellData : (NSDictionary *) data forTweet : (NSString *) tweetName;

- (void) addWebView : (TwitterTableViewController<UIWebViewDelegate> *) delegate;
- (void) removeWebView;

@end
