#import <cassert>

#import <QuartzCore/QuartzCore.h>

#import "VideoThumbnailCell.h"
#import "MWFeedItem.h"

@implementation VideoThumbnailCell

//________________________________________________________________________________________
+ (NSString *) cellReuseIdentifier
{
   return @"VideoThumbnailCell";
}

//________________________________________________________________________________________
- (id) initWithFrame : (CGRect) frame
{
   if (self = [super initWithUIImageView : frame]) {
      //
   }

   return self;
}

//________________________________________________________________________________________
- (NSString *) reuseIdentifier
{
   return [VideoThumbnailCell cellReuseIdentifier];
}

//________________________________________________________________________________________
- (void) setCellData : (MWFeedItem *) itemData
{
   assert(itemData != nil && "setCellData, parameter 'itemData' is nil");
   
   if (itemData.title)
      self.title = itemData.title;
   else
      self.title = @"";//TODO: Check other fields.
   
   if (itemData.image)
      self.imageView.image = itemData.image;
}

@end
