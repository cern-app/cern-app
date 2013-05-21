//
//  AnimatedStackLayout.m
//  CERN
//
//  Created by Timur Pocheptsov on 5/21/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

//Many thanks for the tutorial and this code snippet:
//http://blog.tobiaswiedenmann.com/post/35135290759/stacklayout

#import "AnimatedStackLayout.h"

@implementation AnimatedStackLayout

@synthesize stackCenter, stackFactor;

//________________________________________________________________________________________
- (void) setStackFactor : (CGFloat) aStackFactor
{
   if (aStackFactor < 0.f)
      stackFactor = 0.f;
   else if (aStackFactor > 1.f)
      stackFactor = 1.f;
   else
      stackFactor = aStackFactor;
    
   [self invalidateLayout];
}

//________________________________________________________________________________________
- (void) setStackCenter : (CGPoint) aStackCenter
{
   stackCenter = aStackCenter;
    
   [self invalidateLayout];
}

//________________________________________________________________________________________
-(CGSize) collectionViewContentSize
{
   CGSize contentSize = [super collectionViewContentSize];
       
   if (self.collectionView.bounds.size.width > contentSize.width)
      contentSize.width = self.collectionView.bounds.size.width;
   
   if (self.collectionView.bounds.size.height > contentSize.height)
      contentSize.height = self.collectionView.bounds.size.height;

   return contentSize;
}

//________________________________________________________________________________________
-(NSArray*) layoutAttributesForElementsInRect : (CGRect) rect
{
   NSArray * const attributesArray = [super layoutAttributesForElementsInRect:rect];
   
   // Calculate the new position of each cell based on stackFactor and stackCenter
   for (UICollectionViewLayoutAttributes *attributes in attributesArray) {
      const CGFloat xPosition = stackCenter.x + (attributes.center.x - stackCenter.x) * stackFactor;
      const CGFloat yPosition = stackCenter.y + (attributes.center.y - stackCenter.y) * stackFactor;

      attributes.center = CGPointMake(xPosition, yPosition);
        
      if (attributes.indexPath.row == 0) {
         attributes.alpha = 1.f;
         attributes.zIndex = 1.f; // Put the first cell on top of the stack
      } else {
         attributes.alpha = stackFactor; // fade the other cells out
         attributes.zIndex = 0.0; //Other cells below the first one
      }
   }

   return attributesArray;
}


@end
