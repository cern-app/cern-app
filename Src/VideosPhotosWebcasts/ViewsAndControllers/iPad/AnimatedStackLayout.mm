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

@synthesize stackCenter, stackFactor, inAnimation;

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
- (void) setStackCenterNoUpdate : (CGPoint) aStackCenter
{
   stackCenter = aStackCenter;
   //No need to invalidate layout.   
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
   //stackCenter depends on the view's contentOffset - stack should collapse/expand
   //to the right point on the screen, even after we srcolled an album.
   const CGPoint adjustedStackCenter = CGPointMake(stackCenter.x, stackCenter.y + self.collectionView.contentOffset.y);

   NSArray * const attributesArray = [super layoutAttributesForElementsInRect:rect];
   for (UICollectionViewLayoutAttributes *attributes in attributesArray) {
      const CGFloat xPosition = adjustedStackCenter.x + (attributes.center.x - adjustedStackCenter.x) * stackFactor;
      const CGFloat yPosition = adjustedStackCenter.y + (attributes.center.y - adjustedStackCenter.y) * stackFactor;

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
