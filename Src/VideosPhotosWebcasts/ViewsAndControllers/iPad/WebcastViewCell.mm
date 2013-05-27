#import <cassert>

#import "WebcastViewCell.h"
#import "MWFeedItem.h"

@implementation WebcastViewCell

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
   return @"WebcastViewCell";
}

//________________________________________________________________________________________
- (void) setCellData : (MWFeedItem *) itemData
{
   assert(itemData != nil && "setCellData, parameter 'itemData' is nil");
   //
   if (itemData.title)
      self.title = itemData.title;
   else
      self.title = @"";//TODO: Check other fields.
   
   if (itemData.image)
      self.imageView.image = itemData.image;
}

@end
