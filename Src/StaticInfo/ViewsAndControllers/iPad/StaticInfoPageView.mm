//
//  StaticInfoPageView.m
//  CERN
//
//  Created by Timur Pocheptsov on 5/7/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <algorithm>

#import <QuartzCore/QuartzCore.h>

#import "StaticInfoPageView.h"
#import "StaticInfoTileView.h"

using namespace CernAPP;

const NSUInteger tilesOnPage = 2;
const CGFloat tileShift = 0.2f;

@implementation StaticInfoPageView {
   NSMutableArray *tiles;
}

@synthesize pageNumber, pageRange;

//________________________________________________________________________________________
- (id) initWithFrame : (CGRect) frame
{
   if (self = [super initWithFrame : frame]) {
      //
      self.backgroundColor = [UIColor lightGrayColor];
   }

   return self;
}

//________________________________________________________________________________________
+ (NSRange) suggestRangeForward : (NSArray *) items startingFrom : (NSUInteger) index
{
   //Actually, there is no need in this function, since setPageItems:... setPageItemsFromCache:.. will
   //find this range. Anyway, this function does not create any tile, it just defines the range.
   //For the given '[begin', find the 'end)'

   assert(items != nil && "suggestRangeForward:startingFrom:, parameter 'items' is nil");
   assert(index < items.count && "suggestRangeForward:startingFrom:, parameter 'index' is out of bounds");
   
   const NSUInteger endOfRange = std::min(items.count, index + tilesOnPage);
   
   return NSMakeRange(index, endOfRange - index);
}

//________________________________________________________________________________________
+ (NSRange) suggestRangeBackward : (NSArray *) items endingWith : (NSUInteger) index
{
   //We have the 'end)', find the '[begin'.
   
   assert(items != nil && "suggestRangeBackward:endingWith:, parameter 'items' is nil");
   assert(index <= items.count && "suggestRangeBackward:endingWith:, parameter 'index' is out of bounds");
   
   NSRange range = {};
   
   if (index >= tilesOnPage) {
      range.location = index - tilesOnPage;
      range.length = tilesOnPage;
   } else {
      range.location = 0;
      range.length = index;
   }
   
   return range;
}


//________________________________________________________________________________________
- (NSUInteger) setPageItems : (NSArray *) items startingFrom : (NSUInteger) index
{
   assert(items != nil && "setPageItems:startingFrom:, parameter 'feedItems' is nil");
   assert(index < items.count && "setPageItems:startingFrom:, parameter 'index' is out of range");
   
   if (tiles) {
      for (StaticInfoTileView *v in tiles)
         [v removeFromSuperview];
      [tiles removeAllObjects];
   } else
      tiles = [[NSMutableArray alloc] init];

   const NSUInteger endOfRange = std::min(items.count, index + tilesOnPage);
   
   StaticInfoTileHint hints[tilesOnPage] = {StaticInfoTileHint::scheme1, StaticInfoTileHint::scheme2};

   for (NSUInteger i = index; i < endOfRange; ++i) {
      StaticInfoTileView * const newTile = [[StaticInfoTileView alloc] initWithFrame : CGRect()];
      assert([items[i] isKindOfClass : [NSDictionary class]] &&
             "setPageItems:startingFrom:, item has a wrong type");
      NSDictionary * const itemDict = (NSDictionary *)items[i];
      [newTile setTitle : (NSString *)itemDict[@"Title"]];
      [newTile setText : (NSString *)itemDict[@"Description"]];
      //[newTile setImage:];
      //[newTile setTitle:];
      //[newTile setText:];
      newTile.layoutHint = hints[i - index];
      [tiles addObject : newTile];
      [self addSubview : newTile];
   }

   pageRange.location = index;
   pageRange.length = endOfRange - index;

   return tilesOnPage;
}

//________________________________________________________________________________________
- (NSRange) pageRange
{
   return pageRange;
}

//________________________________________________________________________________________
- (void) setThumbnail : (UIImage *) thumbnailImage forTile : (NSUInteger) tileIndex doLayout : (BOOL) layout
{
#pragma unused(thumbnailImage, tileIndex, layout)
}

//________________________________________________________________________________________
- (BOOL) tileHasThumbnail : (NSUInteger) tileIndex
{
#pragma unused(tileIndex)
   return NO;
}

//________________________________________________________________________________________
- (void) layoutTiles
{
   if (!tiles.count)
      return;

   //Layout tiles
   const CGRect frame = self.frame;

   NSUInteger nItemsPerRow = frame.size.width > frame.size.height ? 2 : 1;
   NSUInteger nRows = nItemsPerRow == 2 ? 1 : 2;
   
   if (tiles.count == 1)
      nItemsPerRow = 1, nRows = 1;
   
   const CGFloat width = frame.size.width / nItemsPerRow;
   const CGFloat height = frame.size.height / nRows;
   
   NSUInteger index = 0;
   for (StaticInfoTileView *tile in tiles) {
      const CGFloat x = (index % nItemsPerRow) * width + 2.f;
      const CGFloat y = (index / nItemsPerRow) * height + 2.f;
      const CGRect frame = CGRectMake(x, y, width - 4.f, height - 4.f);

      tile.frame = frame;
      [tile layoutTile];
      
      ++index;
   }
}

//________________________________________________________________________________________
- (void) explodeTiles : (UIInterfaceOrientation) orientation
{
#pragma unused(orientation)

   if (tiles.count == 1)//No animation for this case, since tile occupies the whole page.
      return;

   const CGPoint pageCenter = self.center;

   for (StaticInfoTileView *tile in tiles) {
      CGPoint tileCenter = [self convertPoint : tile.center toView : self.superview];
      tileCenter.x += tileShift * (tileCenter.x - pageCenter.x);
      tileCenter.y += tileShift * (tileCenter.y - pageCenter.y);
      tileCenter = [self.superview convertPoint : tileCenter toView : self];
      tile.center = tileCenter;
   }

}

//________________________________________________________________________________________
- (void) collectTilesAnimatedForOrientation : (UIInterfaceOrientation) orientation from : (CFTimeInterval) start withDuration : (CFTimeInterval) duration
{
#pragma unused(orientation)
   if (tiles.count == 1)
      return;

   //TODO: test! is center always correct and can I always use it to do these calculations?
   //If not, it's easy (I think) to use view's frames to do the same job.

   const CGPoint pageCenter = self.center;

   NSUInteger index = 0;
   for (StaticInfoTileView *tile in tiles) {
      CGPoint tileCenter = tile.center;
      tileCenter = [self convertPoint : tileCenter toView : self.superview];
      CGPoint endPoint = CGPointMake((tileCenter.x + tileShift * pageCenter.x) / (1.f + tileShift),
                                     (tileCenter.y + tileShift * pageCenter.y) / (1.f + tileShift));
      endPoint = [self.superview convertPoint : endPoint toView : self];
      CABasicAnimation * const animation = [CABasicAnimation animationWithKeyPath : @"position"];
      animation.fromValue = [NSValue valueWithCGPoint : tile.center];
      animation.toValue = [NSValue valueWithCGPoint : endPoint];
      animation.beginTime = start;
      [animation setTimingFunction : [CAMediaTimingFunction functionWithControlPoints : 0.6f : 1.5f : 0.8f : 0.8f]];

      animation.duration = duration;
      [tile.layer addAnimation : animation forKey : [NSString stringWithFormat : @"bounce%u", index]];
      tile.layer.position = endPoint;
      //
      ++index;
   }
}

@end
