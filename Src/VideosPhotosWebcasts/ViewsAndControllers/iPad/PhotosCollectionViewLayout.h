#import <UIKit/UIKit.h>

@interface PhotosCollectionViewLayout : UICollectionViewLayout

@property (nonatomic) UIEdgeInsets itemInsets;
@property (nonatomic) CGSize itemSize;
@property (nonatomic) CGFloat interItemSpacingY;
@property (nonatomic) NSInteger numberOfColumns;
//@property (nonatomic) CGFloat titleHeight;


@end