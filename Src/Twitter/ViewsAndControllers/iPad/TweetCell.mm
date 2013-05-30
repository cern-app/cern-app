#import <cassert>
#import <cmath>

#import <QuartzCore/QuartzCore.h>

#import "TwitterTableViewController.h"
#import "MWFeedItem.h"
#import "TweetCell.h"

const CGFloat smallSizeHMargin = 0.05f;
const CGFloat smallSizeVMargin = 0.005f;
const CGFloat largeSizeHMargin = 0.03f;
const CGFloat largeSizeVMargin = 0.05f;

namespace {

//________________________________________________________________________________________
UIButton *CreateButtons(NSString *normalImageName, NSString *highlightedImageName)
{
   assert(normalImageName != nil && "CreateButtons, parameter 'normalImageName' is nil");
   assert(highlightedImageName != nil && "CreateButtons, parameter 'highlightedImageName' is nil");

   UIButton *btn = [UIButton buttonWithType : UIButtonTypeCustom];
   btn.backgroundColor = [UIColor clearColor];
   btn.opaque = YES;
   
   btn.layer.shadowColor = [UIColor blackColor].CGColor;
   btn.layer.shadowOffset = CGSizeMake(2.f, 2.f);
   btn.layer.shadowOpacity = 0.5f;

   [btn setImage : [UIImage imageNamed: highlightedImageName] forState : UIControlStateHighlighted];
   [btn setImage : [UIImage imageNamed: normalImageName] forState : UIControlStateNormal];
   
   return btn;
}

}

@implementation TweetCell {
   UILabel *tweetNameLabel;
   UILabel *titleLabel;
   UILabel *linkLabel;
   UILabel *dateLabel;
   
   UIFont *smallFont;
   UIFont *largeFont;
   UIFont *smallFontBold;
   UIFont *largeFontBold;
   UIFont *linkFont;
   
   UIButton *retweetBtn;
   UIButton *favBtn;
   
   MWFeedItem *tweet;
}

@synthesize controller;

//________________________________________________________________________________________
- (void) drawRect:(CGRect)rect
{
   const CGFloat w = self.frame.size.width;
   const CGFloat h = self.frame.size.height;
   
   CGContextRef ctx = UIGraphicsGetCurrentContext();

   CGContextSetRGBFillColor(ctx, 0.95f, 0.95f, 0.95f, 1.f);
   
   if (self.cellExpanded) {
      UIBezierPath * const path = [UIBezierPath bezierPathWithRoundedRect :
                                   CGRectMake(w * largeSizeHMargin, h * largeSizeVMargin, w - 2 * w * largeSizeHMargin, h - 2 * h * largeSizeVMargin)
                                   cornerRadius : 10.f];
      CGContextBeginPath(ctx);
      CGContextAddPath(ctx, path.CGPath);
      CGContextFillPath(ctx);
   } else
      CGContextFillRect(ctx, CGRectMake(w * smallSizeHMargin, h * smallSizeVMargin, w - 2 * w * smallSizeHMargin, h - 2 * h * smallSizeVMargin));
}

//________________________________________________________________________________________
+ (CGFloat) collapsedHeight
{
   return 100.f;
}

//________________________________________________________________________________________
+ (CGFloat) expandedHeight
{
   return 300.f;
}

//________________________________________________________________________________________
+ (CGFloat) expandedHeightWithImage
{
   return 400.f;
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
   
   linkLabel = [[UILabel alloc] initWithFrame : CGRect()];
   linkLabel.numberOfLines = 1;
   linkLabel.clipsToBounds = YES;
   linkLabel.textColor = [UIColor brownColor];
   linkLabel.backgroundColor = [UIColor clearColor];
   [self addSubview : linkLabel];
   
   linkLabel.hidden = YES;
   //
   dateLabel = [[UILabel alloc] initWithFrame : CGRect()];
   dateLabel.clipsToBounds = YES;
   dateLabel.numberOfLines = 1;
   dateLabel.textColor = [UIColor blueColor];
   dateLabel.backgroundColor = [UIColor clearColor];
   [self addSubview : dateLabel];
}

//________________________________________________________________________________________
- (void) createButtons
{
   retweetBtn = CreateButtons(@"retweet.png", @"retweet_hi.png");
   [self addSubview : retweetBtn];
   retweetBtn.hidden = YES;
   [retweetBtn addTarget : self action : @selector(reTweet) forControlEvents : UIControlEventTouchDown];
   
   favBtn = CreateButtons(@"favs.png", @"favs_hi.png");
   [self addSubview : favBtn];
   favBtn.hidden = YES;
 //  [favBtn addTarget : self action : @selector(showTweet) forControlEvents : UIControlEventTouchDown];
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
      
      linkFont = [UIFont fontWithName:@"PTSans-Bold" size : 14.f];
      assert(linkFont != nil && "initWithStyle:reuseIdentifier:, linkFont is nil");
      linkLabel.font = linkFont;
      
      [self createButtons];
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
- (void) setCellData : (MWFeedItem *) data forTweet : (NSString *) tweetName
{
   assert(data != nil && "setCellData:forTweet:, parameter 'data' is nil");
   assert(tweetName != nil && "setCellData:forTweet:, parameter 'tweetName' is nil");
   
   assert(tweetNameLabel != nil && "setCellData:forTweet:, tweetNameLabel is nil");
   assert(titleLabel != nil && "setCellData:forTweet:, titleLabel is nil");
   assert(dateLabel != nil && "setCellData:forTweet:, dateLabel is nil");
   
   if (tweetName.length)
      tweetNameLabel.text = tweetName;
   else
      tweetNameLabel.text = @"";
   
   if (data.title.length)
      titleLabel.text = data.title;
   else
      titleLabel.text = @"";

   NSDateFormatter * const dateFormatter = [[NSDateFormatter alloc] init];
   [dateFormatter setDateFormat : @"d MMM. yyyy"];
   dateLabel.text = [dateFormatter stringFromDate : data.date ? data.date : [NSDate date]];
   
   if (data.link.length)
      linkLabel.text = data.link;
   else
      linkLabel.text = @"";
   
   tweet = data;
}

//________________________________________________________________________________________
- (void) layoutUIInFrame : (CGRect) frame
{
   const CGFloat w = frame.size.width;
   
   if (self.cellExpanded) {
      linkLabel.hidden = NO;
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
      
      linkLabel.frame = CGRectMake(frame.origin.x + w * largeSizeHMargin, frame.origin.y + 0.9f * h,
                                   w - 2 * w * largeSizeHMargin, 0.1f * h);
      
      [retweetBtn setHighlighted : NO];
      retweetBtn.hidden = NO;
      retweetBtn.frame = CGRectMake(frame.origin.x + w - 60.f, frame.origin.y + frame.size.height - 50.f, 40.f, 40.f);
      
      [favBtn setHighlighted : NO];
      favBtn.hidden = NO;
      favBtn.frame = CGRectMake(frame.origin.x + w - 100.f, frame.origin.y + frame.size.height - 50.f, 40.f, 40.f);
   } else {
      linkLabel.hidden = YES;
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
      
      linkLabel.frame = CGRectMake(frame.origin.x + w * smallSizeHMargin, 2 * h,
                                   w - 2 * w * largeSizeHMargin, h);
      
      retweetBtn.hidden = YES;
      retweetBtn.frame = CGRectMake(frame.origin.x + w - 60.f, frame.origin.y + frame.size.height - 50.f, 44.f, 44.f);

      favBtn.hidden = YES;
      favBtn.frame = CGRectMake(frame.origin.x + w - 100.f, frame.origin.y + frame.size.height - 50.f, 44.f, 44.f);
   }
}

#pragma mark - User interactions.

//________________________________________________________________________________________
- (void) reTweet
{
   assert(controller != nil && "reTweet, controller is nil");
   assert(tweet != nil && "reTweet, tweet is nil");

   [controller reTweet : tweet];
}

@end
