#import "PhotoSetInfoView.h"

@implementation PhotoSetInfoView

@synthesize descriptionLabel;

//________________________________________________________________________________________
- (id) initWithFrame : (CGRect) frame
{
   if (self = [super initWithFrame : frame]) {
      //
      descriptionLabel = [[UILabel alloc] initWithFrame : CGRect()];
   }

   return self;
}

@end
