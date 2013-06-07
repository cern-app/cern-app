#import <UIKit/UIKit.h>

@interface CollectionSupplementraryView : UICollectionReusableView

+ (NSString *) reuseIdentifierHeader;
+ (NSString *) reuseIdentifierFooter;

@property (nonatomic) IBOutlet UILabel *descriptionLabel;

@end
