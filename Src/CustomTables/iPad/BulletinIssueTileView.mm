#import <cassert>

#import "BulletinIssueTileView.h"

namespace {

//Geometry constant, in percents of self.frame.size.
const CGFloat leftRightMargin = 0.15f;
const CGFloat topMargin = 0.15f;
const CGFloat imageHeight = 0.7f;
const CGFloat textHeight = 0.3f;

//________________________________________________________________________________________
bool IsWideImage(UIImage *image)
{
   //I have another version in FeedItemTileView, it's also a function in an unnamed namespace.
   //Both have the different notion of wide.
   
   assert(image != nil && "IsWideImage, parameter 'image' is nil");
   
   const CGSize imSize = image.size;
   return imSize.width >= 1.5 * imSize.height;
}

}

@implementation BulletinIssueTileView {
   UIImageView *thumbnailView;
   UILabel *title;
}

@synthesize wideImageOnTopHint, squareImageOnLeftHint;

//________________________________________________________________________________________
+ (CGFloat) minImageSize
{
   return 200.f;
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
      UIFont * const titleFont = [UIFont fontWithName : @"PTSans-Bold" size : 40.f];
      assert(titleFont != nil && "initWithFrame:, font for a title is nil");
      title.font = titleFont;
      title.textAlignment = NSTextAlignmentCenter;
      title.backgroundColor = [UIColor clearColor];
      [self addSubview : title];
      //
      self.backgroundColor = [UIColor whiteColor];
   }

   return self;
}

//________________________________________________________________________________________
- (BOOL) setThumbnailImage : (UIImage *) thumbnail
{
   assert(thumbnail != nil && "setThumbnailImage:, parameter 'thumbnail' is nil");

   const CGSize imSize = thumbnail.size;
   if (imSize.width < [self.class minImageSize] || imSize.height < [self.class minImageSize])
      return NO;

   thumbnailView.image = thumbnail;
   [self layoutContents];
   
   return YES;
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

#pragma mark - Debug code.
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
   return CGRect();
}

//________________________________________________________________________________________
- (CGRect) suggestTextGeometry
{
   const CGFloat w = self.frame.size.width;
   const CGFloat h = self.frame.size.height;

   if (!thumbnailView.image)
      return CGRectMake(w * leftRightMargin, h / 2 - textHeight * h / 2, w - 2 * w * leftRightMargin, textHeight * h);

   if (IsWideImage(thumbnailView.image)) {
   
   } else if (squareImageOnLeftHint) {
   
   } else {
   
   }
   
   return CGRect();
}

@end
