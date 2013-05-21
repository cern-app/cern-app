//This layout is from the Collection View tutorial by Bryan Hansen.
//http://www.skeuo.com/uicollectionview-custom-layout-tutorial
//Modified for CERN.app by Timur Pocheptsov.

#import "PhotosCollectionViewLayout.h"
#import "PhotoViewCell.h"

using CernAPP::PhotoCellKind;

//C++ const has an internal linkage, no need in 'static' here.
const NSUInteger RotationCount = 32;
const NSUInteger RotationStride = 3;
const NSUInteger PhotoCellBaseZIndex = 100;

@interface PhotosCollectionViewLayout ()

@property (nonatomic, strong) NSDictionary *layoutInfo;
@property (nonatomic, strong) NSMutableArray *rotations;

- (CGRect) frameForAlbumPhotoAtIndexPath : (NSIndexPath *) indexPath;
//- (CGRect) frameForAlbumTitleAtIndexPath : (NSIndexPath *) indexPath;
//- (CGRect) frameForEmblem;
- (CATransform3D) transformForAlbumPhotoAtIndex : (NSIndexPath *) indexPath;

@end

@implementation PhotosCollectionViewLayout

@synthesize itemInsets, itemSize, interItemSpacingY, numberOfColumns, layoutInfo, rotations;

#pragma mark - Properties

//________________________________________________________________________________________
- (void) setItemInsets : (UIEdgeInsets) anItemInsets
{
   if (!UIEdgeInsetsEqualToEdgeInsets(itemInsets, anItemInsets)) {
      itemInsets = anItemInsets;
      [self invalidateLayout];
   }
}

//________________________________________________________________________________________
- (void) setItemSize : (CGSize) anItemSize
{
   if (!CGSizeEqualToSize(itemSize, anItemSize)) {
      itemSize = anItemSize;
      [self invalidateLayout];
   }
}

//________________________________________________________________________________________
- (void) setInterItemSpacingY : (CGFloat) anInterItemSpacingY
{
   interItemSpacingY = anInterItemSpacingY;
   [self invalidateLayout];
}

//________________________________________________________________________________________
- (void) setNumberOfColumns : (NSInteger) aNumberOfColumns
{
   if (numberOfColumns != aNumberOfColumns) {
      numberOfColumns = aNumberOfColumns;
      [self invalidateLayout];
   }
}

//________________________________________________________________________________________
/*
- (void)setTitleHeight:(CGFloat)titleHeight
{
    if (_titleHeight == titleHeight) return;
    
    _titleHeight = titleHeight;
    
    [self invalidateLayout];
}
*/

#pragma mark - Lifecycle

//________________________________________________________________________________________
- (id) init
{
   if (self = [super init])
      [self setup];
 
   return self;
}

//________________________________________________________________________________________
- (id) initWithCoder : (NSCoder *) aDecoder
{
   if (self = [super init])
      [self setup];
    
   return self;
}

//________________________________________________________________________________________
- (void) setup
{
   itemInsets = UIEdgeInsetsMake(22.0f, 22.0f, 13.0f, 22.0f);
   itemSize = CGSizeMake(125.0f, 125.0f);
   interItemSpacingY = 12.0f;
   
   numberOfColumns = 4;
   //titleHeight = 26.0f;
    
   //Create rotations at load so that they are consistent during prepareLayout
   rotations = [NSMutableArray arrayWithCapacity : RotationCount];
   CGFloat percentage = 0.0f;
   for (NSUInteger i = 0; i < RotationCount; ++i) {
      // ensure that each angle is different enough to be seen
      CGFloat newPercentage = 0.0f;
      do {
         newPercentage = (arc4random() % 220 - 110.f) * 0.0001f;
      } while (fabsf(percentage - newPercentage) < 0.006f);

      percentage = newPercentage;
        
      const CGFloat angle = 2 * M_PI * (1.0f + percentage);
      CATransform3D transform = CATransform3DMakeRotation(angle, 0.0f, 0.0f, 1.0f);
      [rotations addObject:[NSValue valueWithCATransform3D:transform]];
   }
}


#pragma mark - Layout

//________________________________________________________________________________________
- (void) prepareLayout
{
   NSMutableDictionary * const newLayoutInfo = [NSMutableDictionary dictionary];
   NSMutableDictionary * const cellLayoutInfo = [NSMutableDictionary dictionary];
   //NSMutableDictionary * const titleLayoutInfo = [NSMutableDictionary dictionary];
   
   const NSInteger sectionCount = [self.collectionView numberOfSections];
   NSIndexPath *indexPath = [NSIndexPath indexPathForItem:0 inSection:0];
   
   for (NSInteger section = 0; section < sectionCount; ++section) {
      const NSInteger itemCount = [self.collectionView numberOfItemsInSection : section];

      for (NSInteger item = 0; item < itemCount; ++item) {
         indexPath = [NSIndexPath indexPathForItem : item inSection : section];

         UICollectionViewLayoutAttributes *itemAttributes =
         [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];
         itemAttributes.frame = [self frameForAlbumPhotoAtIndexPath:indexPath];
         itemAttributes.transform3D = [self transformForAlbumPhotoAtIndex:indexPath];
         itemAttributes.zIndex = PhotoCellBaseZIndex + itemCount - item;

         cellLayoutInfo[indexPath] = itemAttributes;
         
         /*
         if (!indexPath.item) {
            UICollectionViewLayoutAttributes *titleAttributes =
            [UICollectionViewLayoutAttributes layoutAttributesForSupplementaryViewOfKind:BHPhotoAlbumLayoutAlbumTitleKind withIndexPath:indexPath];
            titleAttributes.frame = [self frameForAlbumTitleAtIndexPath:indexPath];
            titleLayoutInfo[indexPath] = titleAttributes;
         }*/
      }
   }
   
   newLayoutInfo[PhotoCellKind] = cellLayoutInfo;
   //newLayoutInfo[BHPhotoAlbumLayoutAlbumTitleKind] = titleLayoutInfo;
    
   layoutInfo = newLayoutInfo;
}

//________________________________________________________________________________________
- (CGSize) collectionViewContentSize
{
   NSInteger rowCount = [self.collectionView numberOfSections] / self.numberOfColumns;
   // make sure we count another row if one is only partially filled
   if ([self.collectionView numberOfSections] % self.numberOfColumns)
      rowCount++;

   const CGFloat height = itemInsets.top + rowCount * itemSize.height + (rowCount - 1) * self.interItemSpacingY +
                           //rowCount * self.titleHeight +
                          itemInsets.bottom;
    
   return CGSizeMake(self.collectionView.bounds.size.width, height);
}

//________________________________________________________________________________________
- (NSArray *) layoutAttributesForElementsInRect : (CGRect) rect
{
   NSMutableArray * const allAttributes = [NSMutableArray arrayWithCapacity:self.layoutInfo.count];
    
   [self.layoutInfo enumerateKeysAndObjectsUsingBlock : ^(NSString *elementIdentifier, NSDictionary *elementsInfo, BOOL *stop) {
      [elementsInfo enumerateKeysAndObjectsUsingBlock : ^(NSIndexPath *indexPath, UICollectionViewLayoutAttributes *attributes, BOOL *innerStop) {
         if (CGRectIntersectsRect(rect, attributes.frame)) {
            [allAttributes addObject:attributes];
         }
      }];
   }];

   return allAttributes;
}

//________________________________________________________________________________________
- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return layoutInfo[PhotoCellKind][indexPath];
}

/*
//________________________________________________________________________________________
- (UICollectionViewLayoutAttributes *)layoutAttributesForSupplementaryViewOfKind:(NSString *)kind
                                                                     atIndexPath:(NSIndexPath *)indexPath
{
    return self.layoutInfo[BHPhotoAlbumLayoutAlbumTitleKind][indexPath];
}
*/

/*
//________________________________________________________________________________________
- (UICollectionViewLayoutAttributes *)layoutAttributesForDecorationViewOfKind:(NSString*)decorationViewKind atIndexPath:(NSIndexPath *)indexPath
{
    return self.layoutInfo[BHPhotoEmblemKind][indexPath];
}
*/


#pragma mark - Private

//________________________________________________________________________________________
- (CGRect)frameForAlbumPhotoAtIndexPath:(NSIndexPath *)indexPath
{
   const NSInteger row = indexPath.section / self.numberOfColumns;
   const NSInteger column = indexPath.section % self.numberOfColumns;
   
   CGFloat spacingX = self.collectionView.bounds.size.width - self.itemInsets.left - self.itemInsets.right -
                      (self.numberOfColumns * self.itemSize.width);
    
   if (numberOfColumns > 1)
      spacingX = spacingX / (numberOfColumns - 1);
    
   const CGFloat originX = floorf(self.itemInsets.left + (self.itemSize.width + spacingX) * column);
   const CGFloat originY = floor(self.itemInsets.top + (self.itemSize.height + /*self.titleHeight*/ + self.interItemSpacingY) * row);
    
   return CGRectMake(originX, originY, self.itemSize.width, self.itemSize.width);
}

/*
//________________________________________________________________________________________
- (CGRect)frameForAlbumTitleAtIndexPath:(NSIndexPath *)indexPath
{
   CGRect frame = [self frameForAlbumPhotoAtIndexPath:indexPath];
    frame.origin.y += frame.size.height;
    frame.size.height = self.titleHeight;
    
    return frame;
}*/

//________________________________________________________________________________________
- (CATransform3D) transformForAlbumPhotoAtIndex : (NSIndexPath *) indexPath
{
   NSInteger offset = (indexPath.section * RotationStride + indexPath.item);
   return [self.rotations[offset % RotationCount] CATransform3DValue];
}

@end
