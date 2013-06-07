#import <QuartzCore/QuartzCore.h>

#import "PhotoViewCell.h"

//TODO: this class should be merged with PhotoGridViewCell (or replace it).

@implementation PhotoViewCell

@synthesize imageView;

//________________________________________________________________________________________
+ (NSString *) cellReuseIdentifier
{
   return @"PhotoViewCell";
}

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

      self.layer.rasterizationScale = [UIScreen mainScreen].scale;
      self.layer.shouldRasterize = YES;
        
      imageView = [[UIImageView alloc] initWithFrame : self.bounds];
      imageView.backgroundColor = [UIColor darkGrayColor];
      imageView.contentMode = UIViewContentModeScaleAspectFill;
      imageView.clipsToBounds = YES;
      
      imageView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
                                   UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
                                   UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
      self.autoresizesSubviews = YES;
      
        
      [self.contentView addSubview : self.imageView];
   }

   return self;
}

//________________________________________________________________________________________
- (NSString *) reuseIdentifier
{
   return [PhotoViewCell cellReuseIdentifier];
}

//________________________________________________________________________________________
- (void) prepareForReuse
{
   imageView.image = nil;
}

@end
