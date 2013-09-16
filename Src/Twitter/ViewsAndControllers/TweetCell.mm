#import <cassert>
#import <cmath>

#import <QuartzCore/QuartzCore.h>

#import "TwitterTableViewController.h"
#import "DeviceCheck.h"
#import "MWFeedItem.h"
#import "TweetCell.h"

const CGFloat smallSizeVMargin = 0.005f;
const CGFloat largeSizeVMargin = 0.05f;

@implementation TweetCell {
   UIWebView *webView;
   UILabel *tweetNameLabel;
   UILabel *titleLabel;
   UILabel *dateLabel;
   
   UIFont *smallFont;
   UIFont *largeFont;
   UIFont *smallFontBold;
   UIFont *largeFontBold;
      
   NSURLRequest *webViewRequest;
   
   CALayer *backgroundLayer;
}

@synthesize controller;

//________________________________________________________________________________________
- (void) drawRect : (CGRect) rect
{
   if (CernAPP::SystemVersionGreaterThanOrEqualTo(@"7.0"))
      return;
   
   const CGFloat smallSizeHMargin = CernAPP::SystemVersionGreaterThanOrEqualTo(@"7.0") ? 0.015f : 0.05f;
   const CGFloat largeSizeHMargin = CernAPP::SystemVersionGreaterThanOrEqualTo(@"7.0") ? 0.008f : 0.03f;

   const CGFloat w = self.frame.size.width;
   const CGFloat h = self.frame.size.height;
   
   CGContextRef ctx = UIGraphicsGetCurrentContext();

   CGContextSetRGBFillColor(ctx, 0.95f, 0.95f, 0.95f, 1.f);
   
   if (self.cellExpanded) {
      //A cell is never expanded in the iPhone version, so I'm not checking idiom here.
      UIBezierPath * const path = [UIBezierPath bezierPathWithRoundedRect :
                                   CGRectMake(w * largeSizeHMargin, h * largeSizeVMargin, w - 2 * w * largeSizeHMargin, h - 2 * h * largeSizeVMargin)
                                   cornerRadius : 10.f];
      CGContextBeginPath(ctx);
      CGContextAddPath(ctx, path.CGPath);
      CGContextFillPath(ctx);
   } else {
      if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
         CGContextFillRect(ctx, CGRectMake(w * smallSizeHMargin, h * smallSizeVMargin, w - 2 * w * smallSizeHMargin, h - 2 * h * smallSizeVMargin));
      else
         CGContextFillRect(ctx, CGRectMake(0.f, h * smallSizeVMargin, w, h - 2 * h * smallSizeVMargin));
   }
}

//________________________________________________________________________________________
+ (CGFloat) collapsedHeight
{
   return 100.f;
}

//________________________________________________________________________________________
+ (CGFloat) expandedHeight
{
   return 500.f;
}

//________________________________________________________________________________________
+ (NSString *) reuseIdentifier
{
   return @"TweetCell";
}

//________________________________________________________________________________________
- (void) createLabels
{
   tweetNameLabel = [[UILabel alloc] initWithFrame : CGRect()];
   tweetNameLabel.clipsToBounds = YES;
   tweetNameLabel.textColor = [UIColor blackColor];
   tweetNameLabel.textAlignment = NSTextAlignmentLeft;
   tweetNameLabel.backgroundColor = [UIColor clearColor];
   tweetNameLabel.numberOfLines = 1;
   [self addSubview : tweetNameLabel];

   
   titleLabel = [[UILabel alloc] initWithFrame : CGRect()];
   titleLabel.clipsToBounds = YES;
   titleLabel.textColor = [UIColor darkGrayColor];
   titleLabel.textAlignment = NSTextAlignmentLeft;
   titleLabel.backgroundColor = [UIColor clearColor];
   [self addSubview : titleLabel];
   //
   dateLabel = [[UILabel alloc] initWithFrame : CGRect()];
   dateLabel.clipsToBounds = YES;
   dateLabel.numberOfLines = 1;
   dateLabel.textColor = [UIColor blueColor];
   dateLabel.backgroundColor = [UIColor clearColor];
   [self addSubview : dateLabel];
}

//________________________________________________________________________________________
- (id) initWithStyle : (UITableViewCellStyle) style reuseIdentifier : (NSString *) reuseIdentifier
{
   if (self = [super initWithStyle:style reuseIdentifier : reuseIdentifier]) {
      //Initialization code
      self.backgroundColor = [UIColor clearColor];

      [self createLabels];
      
      //Custom fonts.
      smallFont = [UIFont fontWithName:@"PTSans-Caption" size : 12.f];
      assert(smallFont != nil && "initWithStyle:reuseIdentifier:, smallFont is nil");
      largeFont = [UIFont fontWithName:@"PTSans-Caption" size : 22.f];
      assert(largeFont != nil && "initWithStyle:reuseIdentifier:, largeFont is nil");
      
      smallFontBold = [UIFont fontWithName:@"PTSans-Bold" size : 16.f];
      assert(smallFontBold != nil && "initWithStyle:reuseIdentifier:, smallFontBold is nil");
      largeFontBold = [UIFont fontWithName:@"PTSans-Bold" size : 26.f];
      assert(largeFontBold != nil && "initWithStyle:reuseIdentifier:, largeFontBold is nil");
      
      webViewRequest = nil;
      
      if (CernAPP::SystemVersionGreaterThanOrEqualTo(@"7.0")) {
         self.layer.borderWidth = 1.f;
         self.layer.borderColor = [UIColor lightGrayColor].CGColor;
      }
   }

   return self;
}

//________________________________________________________________________________________
- (BOOL) cellExpanded
{
   return std::abs(self.frame.size.height - [TweetCell collapsedHeight]) > 0.1f;
}

//________________________________________________________________________________________
- (void) setSelected : (BOOL) selected animated : (BOOL)animated
{
   [super setSelected : selected animated : animated];
    // Configure the view for the selected state
}

//________________________________________________________________________________________
- (void) layoutSubviews
{
   const CGFloat smallSizeHMargin = CernAPP::SystemVersionGreaterThanOrEqualTo(@"7.0") ? 0.015f : 0.05f;
   const CGFloat largeSizeHMargin = CernAPP::SystemVersionGreaterThanOrEqualTo(@"7.0") ? 0.008f : 0.03f;

   const CGRect frame = self.frame;
   const CGFloat w = frame.size.width;
   const CGFloat h = frame.size.height;
   
   CGRect adjustedFrame = {};
   if (self.cellExpanded)
      adjustedFrame = CGRectMake(w * largeSizeHMargin, h * largeSizeVMargin, w - 2 * w * largeSizeHMargin, h - 2 * h * largeSizeVMargin);
   else
      adjustedFrame = CGRectMake(w * smallSizeHMargin, h * smallSizeVMargin, w - 2 * w * smallSizeHMargin, h - 2 * h * smallSizeVMargin);

   [self layoutUIInFrame : adjustedFrame];
}

//________________________________________________________________________________________
- (void) setCellData : (NSDictionary *) data forTweet : (NSString *) tweetName
{
   assert(data != nil && "setCellData:forTweet:, parameter 'data' is nil");
   assert(data[@"created_at"] != nil && "setCellData:forTweet:, no 'created_at'");
   assert(data[@"text"] != nil && "setCellData:forTweet:, no 'text'");
   assert(data[@"link"] != nil && "setCellData:forTweet:, no 'link'");
   
   assert(tweetName != nil && "setCellData:forTweet:, parameter 'tweetName' is nil");
   
   assert(tweetNameLabel != nil && "setCellData:forTweet:, tweetNameLabel is nil");
   assert(titleLabel != nil && "setCellData:forTweet:, titleLabel is nil");
   assert(dateLabel != nil && "setCellData:forTweet:, dateLabel is nil");
   
   if (tweetName.length)
      tweetNameLabel.text = tweetName;
   else
      tweetNameLabel.text = @"";
   
   titleLabel.text = (NSString *)data[@"text"];

   NSDateFormatter * const dateFormatter = [[NSDateFormatter alloc] init];
   [dateFormatter setDateFormat : @"d MMM. yyyy"];
   dateLabel.text = [dateFormatter stringFromDate : (NSDate *)data[@"created_at"]];
   
   webViewRequest = (NSURLRequest *)data[@"link"];
}

//________________________________________________________________________________________
- (void) layoutUIInFrame : (CGRect) frame
{
   const CGFloat largeSizeHMargin = CernAPP::SystemVersionGreaterThanOrEqualTo(@"7.0") ? 0.008f : 0.03f;

   const CGFloat w = frame.size.width;
   
   if (self.cellExpanded) {
      tweetNameLabel.hidden = YES;
      titleLabel.hidden = YES;
      dateLabel.hidden = YES;
      
      tweetNameLabel.font = largeFontBold;
      titleLabel.font = largeFont;
      dateLabel.font = largeFont;

      const CGFloat h = frame.size.height - 2 * frame.size.height * largeSizeHMargin;//We place labels in this rectangle.
      tweetNameLabel.frame = CGRectMake(frame.origin.x + w * largeSizeHMargin, frame.origin.y,
                                        w - 2 * w * largeSizeHMargin, h * 0.2f);

      titleLabel.numberOfLines = 4;
      titleLabel.frame = CGRectMake(frame.origin.x + w * largeSizeHMargin, frame.origin.y + 0.2f * h,
                                    w - 2 * w * largeSizeHMargin, h * 0.6f);
      
      const CGSize dateTextSize = [dateLabel.text sizeWithFont : dateLabel.font];
      dateLabel.frame = CGRectMake(frame.origin.x + w - dateTextSize.width * 1.1f, frame.origin.y,
                                   dateTextSize.width * 1.1f, 0.2f * h);
      
   } else {
      tweetNameLabel.hidden = NO;
      titleLabel.hidden = NO;
      dateLabel.hidden = NO;

      tweetNameLabel.font = smallFontBold;
      titleLabel.font = smallFont;
      dateLabel.font = smallFont;
      
      const CGFloat h = frame.size.height / 3;
      tweetNameLabel.frame = CGRectMake(frame.origin.x + w * largeSizeHMargin, frame.origin.y,
                                        w - 2 * w * largeSizeHMargin, h);
      titleLabel.numberOfLines = 2;
      titleLabel.frame = CGRectMake(frame.origin.x + w * largeSizeHMargin, frame.origin.y + h,
                                    w - 2 * w * largeSizeHMargin, h);
      const CGSize dateTextSize = [dateLabel.text sizeWithFont : dateLabel.font];
      dateLabel.frame = CGRectMake(frame.origin.x + frame.size.width - dateTextSize.width * 1.1f,
                                   frame.origin.y, dateTextSize.width * 1.1f, h);
   }
}

//________________________________________________________________________________________
- (void) addWebView : (TwitterTableViewController<UIWebViewDelegate> *) delegate
{
   assert(webViewRequest != nil && "addWebView:, webViewRequest is nil");

   const CGFloat largeSizeHMargin = CernAPP::SystemVersionGreaterThanOrEqualTo(@"7.0") ? 0.008f : 0.03f;

   const CGFloat w = self.frame.size.width;
   const CGFloat h = self.frame.size.height;

   const CGRect adjustedFrame = CGRectMake(w * largeSizeHMargin * 1.5, h * largeSizeVMargin * 1.5, w - 3 * w * largeSizeHMargin, h - 3 * h * largeSizeVMargin);
   if (webView)
      [self removeWebView];
   
   webView = [[UIWebView alloc] initWithFrame : adjustedFrame];
   [self addSubview : webView];
   webView.delegate = delegate;
   webView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
                              UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
                              UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
   
   
   //webView.delegate = self;
   [webView loadRequest : webViewRequest];
}

//________________________________________________________________________________________
- (void) removeWebView
{
   if (webView) {
      [webView removeFromSuperview];
      webView.delegate = nil;
   }

   webView = nil;
}

@end
