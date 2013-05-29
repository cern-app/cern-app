#import <cassert>
#import <cmath>

#import <QuartzCore/QuartzCore.h>

#import "MWFeedItem.h"
#import "TweetCell.h"

const CGFloat smallSizeHMargin = 0.075f;
const CGFloat smallSizeVMargin = 0.005f;
const CGFloat largeSizeHMargin = 0.06;
const CGFloat largeSizeVMargin = 0.05f;

@implementation TweetCell {
   CALayer *layer;
   
   UILabel *titleLabel;
   UILabel *linkLabel;
   UILabel *dateLabel;
   UIButton *openBtn;
   
   UIFont *smallFont;
   UIFont *largeFont;
   UIFont *smallFontBold;
   UIFont *largeFontBold;
}

//________________________________________________________________________________________
+ (CGFloat) collapsedHeight
{
   return 120.f;
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
- (id) initWithStyle : (UITableViewCellStyle) style reuseIdentifier : (NSString *) reuseIdentifier
{
   if (self = [super initWithStyle:style reuseIdentifier : reuseIdentifier]) {
      //Initialization code
      self.backgroundColor = [UIColor clearColor];
      layer = [CALayer layer];
      layer.backgroundColor = [UIColor colorWithRed : 0.95f green : 0.95f blue : 0.95f alpha : 1.f].CGColor;
      [self.layer addSublayer : layer];
      
      titleLabel = [[UILabel alloc] initWithFrame : CGRect()];
      titleLabel.clipsToBounds = YES;
      titleLabel.textColor = [UIColor blackColor];
      titleLabel.textAlignment = NSTextAlignmentCenter;
      titleLabel.backgroundColor = [UIColor clearColor];
      [self addSubview : titleLabel];
      
      linkLabel = [[UILabel alloc] initWithFrame : CGRect()];
      linkLabel.numberOfLines = 1;
      linkLabel.clipsToBounds = YES;
      linkLabel.textColor = [UIColor brownColor];
      linkLabel.backgroundColor = [UIColor clearColor];
      [self addSubview : linkLabel];
      
      linkLabel.hidden = YES;
      
      UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget : self action : @selector(showTweet)];
      [linkLabel addGestureRecognizer : tapRecognizer];

      //
      dateLabel = [[UILabel alloc] initWithFrame : CGRect()];
      dateLabel.clipsToBounds = YES;
      dateLabel.numberOfLines = 1;
      dateLabel.textColor = [UIColor blueColor];
      dateLabel.backgroundColor = [UIColor clearColor];
      [self addSubview : dateLabel];
      //Custom fonts.
      smallFont = [UIFont fontWithName:@"PTSans-Caption" size : 16.f];
      assert(smallFont != nil && "initWithStyle:reuseIdentifier:, smallFont is nil");
      largeFont = [UIFont fontWithName:@"PTSans-Caption" size : 28.f];
      assert(largeFont != nil && "initWithStyle:reuseIdentifier:, largeFont is nil");
      
      smallFontBold = [UIFont fontWithName:@"PTSans-Bold" size : 16.f];
      assert(smallFontBold != nil && "initWithStyle:reuseIdentifier:, smallFontBold is nil");
      largeFontBold = [UIFont fontWithName:@"PTSans-Bold" size : 28.f];
      assert(largeFontBold != nil && "initWithStyle:reuseIdentifier:, largeFontBold is nil");
   }

   return self;
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
   if (std::abs(h - [TweetCell collapsedHeight]) > 0.1f) {//hehe
      adjustedFrame = CGRectMake(w * largeSizeHMargin, h * largeSizeVMargin, w - 2 * w * largeSizeHMargin, h - 2 * h * largeSizeVMargin);
      layer.cornerRadius = 10.f;
      
   } else {
      adjustedFrame = CGRectMake(w * smallSizeHMargin, h * smallSizeVMargin, w - 2 * w * smallSizeHMargin, h - 2 * h * smallSizeVMargin);
      layer.cornerRadius = 0.f;
   }

   layer.frame = adjustedFrame;
   [self layoutUIInFrame : adjustedFrame];
}

//________________________________________________________________________________________
- (void) setCellData : (MWFeedItem *) data
{
   assert(data != nil && "setCellData:, parameter 'data' is nil");
   assert(titleLabel != nil && "setCellData:, titleLabel is nil");
   assert(dateLabel != nil && "setCellData:, dateLabel is nil");
   
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
}

//________________________________________________________________________________________
- (void) layoutUIInFrame : (CGRect) frame
{
   const CGFloat w = frame.size.width;
   const CGFloat h = frame.size.height;
   
   if (std::abs(self.frame.size.height - [TweetCell collapsedHeight]) > 0.1f) {
      linkLabel.hidden = NO;
      titleLabel.font = largeFontBold;
      dateLabel.font = largeFont;
      linkLabel.font = largeFont;

      titleLabel.numberOfLines = 4;
      titleLabel.frame = CGRectMake(frame.origin.x + w * largeSizeHMargin, frame.origin.y + h * largeSizeVMargin,
                                    w - 2 * w * largeSizeHMargin, h - 2 * h * largeSizeVMargin);
   } else {
      linkLabel.hidden = YES;
      titleLabel.font = smallFontBold;
      dateLabel.font = smallFont;
      
      titleLabel.numberOfLines = 1;
      titleLabel.frame = CGRectMake(frame.origin.x + w * smallSizeHMargin, frame.origin.y + h * smallSizeVMargin,
                                    w - 2 * w * smallSizeHMargin, h - 2 * h * smallSizeVMargin);
   }
}

#pragma mark - User interactions.

//________________________________________________________________________________________
- (void) showTweet
{
   NSLog(@"tapped!");
}

@end
