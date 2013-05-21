#import <QuartzCore/QuartzCore.h>

#import "PhotoViewCell.h"

//TODO: this class should be merged with PhotoGridViewCell (or replace it).

@implementation PhotoViewCell

@synthesize imageView;

#pragma mark - Lifecycle.

//________________________________________________________________________________________
- (id) initWithFrame : (CGRect) frame
{
   if (self = [super initWithFrame : frame]) {
      self.backgroundColor = [UIColor colorWithWhite:0.85f alpha:1.f];

      self.layer.borderColor = [UIColor whiteColor].CGColor;
      self.layer.borderWidth = 3.f;
      self.layer.shadowColor = [UIColor blackColor].CGColor;
      self.layer.shadowRadius = 3.f;
      self.layer.shadowOffset = CGSizeMake(-2.f, -2.f);
      self.layer.shadowOpacity = 0.5f;

      //To show stacked images (views) I'll use rotation transformation.
      //To anti-alias edges, we rasterize (thanks to Bryan Hansen for his nice
      //article and tutorial: http://www.skeuo.com/uicollectionview-custom-layout-tutorial).
      self.layer.rasterizationScale = [UIScreen mainScreen].scale;
      self.layer.shouldRasterize = YES;
        
      imageView = [[UIImageView alloc] initWithFrame : self.bounds];
      imageView.backgroundColor = [UIColor darkGrayColor];
      imageView.contentMode = UIViewContentModeScaleAspectFill;
      imageView.clipsToBounds = YES;
        
      [self.contentView addSubview : self.imageView];
   }

   return self;
}

//________________________________________________________________________________________
- (NSString *) reuseIdentifier
{
   return @"PhotoViewCell";
}

@end
