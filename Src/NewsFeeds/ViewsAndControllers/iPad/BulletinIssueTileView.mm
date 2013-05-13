#import <cassert>

#import "BulletinIssueTileView.h"
#import "FeedItemTileView.h"//TODO: move a constant (for NSNotification center) into utilities.

namespace CernAPP {

NSString * const bulletinIssueSelectionNotification = @"CernAPP_BulletinIssueSelectionNotification";

}

namespace {

//Geometry constant, in percents of self.frame.size.
const CGFloat leftRightMargin = 0.1f;
const CGFloat topMargin = 0.1f;
const CGFloat imageHeight = 0.7f;
const CGFloat textHeight = 0.1f;

//________________________________________________________________________________________
bool IsWideImage(UIImage *image)
{
   //I have another version in FeedItemTileView, it's also a function in an unnamed namespace.
   //Both have the different notion of wide.
   
   assert(image != nil && "IsWideImage, parameter 'image' is nil");
   
   const CGSize imSize = image.size;
   return imSize.width >= 1.5 * imSize.height && imSize.width > 300.f;
}

//________________________________________________________________________________________
bool IsWideView(UIView *view)
{
   assert(view != nil && "IsWideView, parameter 'view' is nil");
   
   return view.frame.size.width >= 1.5 * view.frame.size.height;
}

}

@implementation BulletinIssueTileView {
   UIImageView *thumbnailView;
   UILabel *title;
}

@synthesize wideImageOnTopHint, squareImageOnLeftHint, issueNumber;

//________________________________________________________________________________________
+ (CGFloat) minImageSize
{
   return 300.f;
}

//________________________________________________________________________________________
- (id) initWithFrame : (CGRect) frame
{
   if (self = [super initWithFrame : frame]) {
      thumbnailView = [[UIImageView alloc] initWithFrame : CGRect()];
      thumbnailView.contentMode = UIViewContentModeScaleAspectFill;
      thumbnailView.clipsToBounds = YES;
      [self addSubview : thumbnailView];
      
      title = [[UILabel alloc] initWithFrame : CGRect()];
      //
      UIFont * const titleFont = [UIFont fontWithName : @"PTSans-Bold" size : 30.f];
      assert(titleFont != nil && "initWithFrame:, font for a title is nil");
      title.font = titleFont;
      title.textAlignment = NSTextAlignmentCenter;
      title.backgroundColor = [UIColor clearColor];
      [self addSubview : title];
      //
      self.backgroundColor = [UIColor whiteColor];
      
      UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget : self action : @selector(showBulletinIssue)];
      [self addGestureRecognizer : tapRecognizer];
   }

   return self;
}

//________________________________________________________________________________________
- (void) setThumbnailImage : (UIImage *) thumbnail
{
   assert(thumbnail != nil && "setThumbnailImage:, parameter 'thumbnail' is nil");

   const CGSize imSize = thumbnail.size;
   if (imSize.width < [self.class minImageSize] || imSize.height < [self.class minImageSize])
      return;

   thumbnailView.image = thumbnail;
   [self layoutContents];
}

//________________________________________________________________________________________
- (BOOL) hasThumbnailImage
{
   return thumbnailView.image != nil;
}

//________________________________________________________________________________________
- (void) setTileText : (NSString *) text
{
   assert(text != nil && "setTileText:, parameter 'text' is nil");
   assert(title != nil && "setTitleText:, title is nil");
   //
   title.text = text;
}

//________________________________________________________________________________________
- (void) layoutContents
{
   thumbnailView.frame = [self suggestImageGeometry];
   title.frame = [self suggestTextGeometry];
}

#pragma mark - Gradient fill.
/*
//________________________________________________________________________________________
- (void) drawRect : (CGRect)rect
{
   // Drawing code
   CGContextRef ctx = UIGraphicsGetCurrentContext();

   CGContextSetRGBFillColor(ctx, 1.f, 1.f, 1.f, 1.f);
   CGContextFillRect(ctx, rect);

   CGContextSetRGBStrokeColor(ctx, 0.f, 0.f, 0.f ,1.f);
   
   CGContextBeginPath(ctx);
   CGContextMoveToPoint(ctx, 0.f, 0.f);
   CGContextAddLineToPoint(ctx, rect.size.width, rect.size.height);
   CGContextStrokePath(ctx);
}
*/
#pragma mark - Aux.

//________________________________________________________________________________________
- (CGRect) suggestImageGeometry
{
   //TODO.
   const CGFloat w = self.frame.size.width;
   const CGFloat h = self.frame.size.height;
   
   if (!thumbnailView.image)
      return CGRect();
   
   CGRect imageRect = {};
   if (IsWideImage(thumbnailView.image)) {
      if (wideImageOnTopHint)
         imageRect = CGRectMake(w * leftRightMargin, h * topMargin, w - 2 * leftRightMargin * w, imageHeight * h);
      else
         imageRect = CGRectMake(w * leftRightMargin, (topMargin + textHeight) * h, w - 2 * leftRightMargin * w, imageHeight * h);
   } else if (IsWideView(self)) {
      if (squareImageOnLeftHint)
         imageRect = CGRectMake(w * leftRightMargin, h * topMargin, w / 2 - w * leftRightMargin, h - 2 * topMargin * h);
      else
         imageRect = CGRectMake(w / 2, h * topMargin, w / 2 - w * leftRightMargin, h - 2 * topMargin * h);
   } else//Similar to wideImageOnTopHint.
      imageRect = CGRectMake(leftRightMargin * w, topMargin * h, w - 2 * w * leftRightMargin, h * imageHeight);

   return imageRect;
}

//________________________________________________________________________________________
- (CGRect) suggestTextGeometry
{
   const CGFloat w = self.frame.size.width;
   const CGFloat h = self.frame.size.height;

   if (!thumbnailView.image)
      return CGRectMake(w * leftRightMargin, h / 2 - textHeight * h / 2, w - 2 * w * leftRightMargin, textHeight * h);

   CGRect textRect = {};
   if (IsWideImage(thumbnailView.image)) {
      if (wideImageOnTopHint)
         textRect = CGRectMake(w * leftRightMargin, h * topMargin + imageHeight * h, w - 2 * leftRightMargin * w, textHeight * h);
      else
         textRect = CGRectMake(w * leftRightMargin, topMargin * h, w - 2 * leftRightMargin * w, textHeight * h);
   } else if (IsWideView(self)) {
      if (squareImageOnLeftHint)
         textRect = CGRectMake(w / 2, h / 2 - textHeight * h / 2, w / 2 - w * leftRightMargin, textHeight * h);
      else
         textRect = CGRectMake(w * leftRightMargin, h / 2 - textHeight * h / 2, w / 2 - leftRightMargin * w, textHeight * h);
   } else
      textRect = CGRectMake(w * leftRightMargin, h * topMargin + imageHeight * h, w - 2 * leftRightMargin * w, textHeight * h);
   
   return textRect;
}

#pragma mark - Gestures.

//________________________________________________________________________________________
- (void) showBulletinIssue
{
   NSNumber * const num = [NSNumber numberWithUnsignedInteger : issueNumber];
   [[NSNotificationCenter defaultCenter] postNotificationName : CernAPP::bulletinIssueSelectionNotification object : num];
}


@end
