#import "CollectionSupplementraryView.h"

@implementation CollectionSupplementraryView

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

//________________________________________________________________________________________
+ (NSString *) reuseIdentifierHeader
{
   return @"CollectionSupplementraryViewHeader";
}

//________________________________________________________________________________________
+ (NSString *) reuseIdentifierFooter
{
   return @"CollectionSupplementraryViewFooter";
}

@end
