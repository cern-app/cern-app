#import <cassert>

#import "BulletinIssueTileView.h"

namespace CernAPP {

//Geometry constant, in percents of self.frame.size.
const CGFloat leftRightMargin = 0.15f;
const CGFloat topMargin = 0.15f;
const CGFloat imageHeight = 0.7f;

}

@implementation BulletinIssueTileView {
   UIImageView *thumbnailView;
   NSString *tileText;
}

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
- (void) setTileText : (NSString *) text
{
   assert(text != nil && "setTileText:, parameter 'text' is nil");
}

//________________________________________________________________________________________
- (void) layoutContents
{
   using namespace CernAPP;
   
   const CGFloat w = self.frame.size.width;
   const CGFloat h = self.frame.size.height;

   thumbnailView.frame = CGRectMake(w * leftRightMargin, h * topMargin, w - 2 * leftRightMargin * w, h * imageHeight);
   
   //Text frame?
}

#pragma mark - Debug code.

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


@end
