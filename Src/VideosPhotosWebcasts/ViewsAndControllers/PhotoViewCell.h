#import <UIKit/UIKit.h>

//TODO: merge this with PhotoGridViewCell (iPhone version) and place it one level up (in ViewsAndControllers dir).

@interface PhotoViewCell : UICollectionViewCell

+ (NSString *) cellReuseIdentifier;

@property (nonatomic, strong, readonly) IBOutlet UIImageView *imageView;

@end
