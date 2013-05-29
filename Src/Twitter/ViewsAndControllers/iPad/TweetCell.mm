#import <cmath>

#import <QuartzCore/QuartzCore.h>

#import "TweetCell.h"

const CGFloat smallSizeHMargin = 0.075f;
const CGFloat smallSizeVMargin = 0.005f;
const CGFloat largeSizeHMargin = 0.06;
const CGFloat largeSizeVMargin = 0.05f;

@implementation TweetCell {
   CALayer *layer;
}

//________________________________________________________________________________________
+ (CGFloat) collapsedHeight
{
   return 150.f;
}

//________________________________________________________________________________________
+ (CGFloat) expandedHeight
{
   return 250.f;
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
- (void) setFrame : (CGRect)frame
{
   [super setFrame : frame];
   [self setCellFrame : frame];
}

//________________________________________________________________________________________
- (void) setCellFrame : (CGRect) frame
{
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
}

@end
