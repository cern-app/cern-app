//
//  BulletinPageView.m
//  CERN
//
//  Created by Timur Pocheptsov on 4/11/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

#import "BulletinIssueTileView.h"
#import "BulletinPageView.h"

@implementation BulletinPageView {
   NSMutableArray *tiles;
}

const CGFloat tileShift = 0.2f;

@synthesize pageNumber, pageRange;

//________________________________________________________________________________________
+ (NSRange) suggestRangeForward : (NSArray *) items startingFrom : (NSUInteger) index
{
   //At the moment, page in the bulletin has 1, 2, or at most 3 issues per page.
   assert(items != nil && "suggestRangeForward:startingFrom:, parameter 'items' is nil");
   assert(index < items.count && "suggestRangeForward:startingFrom:, parameter 'index' is out of bounds");

   if (items.count - index >= 3)
      return NSMakeRange(index, 3);
   
   return NSMakeRange(index, items.count - index);
}

//________________________________________________________________________________________
+ (NSRange) suggestRangeBackward : (NSArray *) items endingWith : (NSUInteger) index
{
   assert(items != nil && "suggestRangeBackward:endingWith:, parameter 'items' is nil");
   assert(index < items.count && "suggestRangeBackward:endingWith:, parameter 'index' is out of bounds");
   
   if (index >= 3)
      return NSMakeRange(index - 3, 3);
   
   return NSMakeRange(0, index);
}

//________________________________________________________________________________________
- (id) initWithFrame : (CGRect) frame
{
   if (self = [super initWithFrame : frame]) {
      // Initialization code
      pageRange = NSRange();
      tiles = [[NSMutableArray alloc] init];
   }

   return self;
}

//________________________________________________________________________________________
- (NSUInteger) setPageItems : (NSArray *) items startingFrom : (NSUInteger) index
{
   assert(items != nil && "setPageItems:startingFrom:, parameter 'feedItems' is nil");
   assert(index < items.count && "setPageItems:startingFrom:, parameter 'index' is out of bounds");

   //Items in the 'items' array are arrays with MWFeedItems sorted by the date.
   if (!tiles)
      tiles = [[NSMutableArray alloc] init];
   else {
      for (BulletinIssueTileView *tile in tiles)
         [tile removeFromSuperview];
      [tiles removeAllObjects];
   }
   
   pageRange = [BulletinPageView suggestRangeForward : items startingFrom : index];

   for (NSUInteger i = 0; i < pageRange.length; ++i, ++index) {
      //Using the array of MWFeedItems, find the issue's date and create a tile.
      //Create a tile.
      BulletinIssueTileView * const newTile = [[BulletinIssueTileView alloc] initWithFrame : CGRect()];
      //Set the image if any.
      //Set the text ('Week of xxxx : yyy articles').
      [self addSubview : newTile];
      [tiles addObject : newTile];
   }

   return pageRange.length;
}

//________________________________________________________________________________________
- (void) setThumbnail : (UIImage *) thumbnailImage forTile : (NSUInteger) tileIndex
{
   assert(thumbnailImage != nil && "setThumbnail:forTile:, parameter 'thumbnailImge' is nil");
   assert(tileIndex < tiles.count && "setThumbnail:forTile:, parameter 'tileIndex' is out of bounds");
   
   //
   //
   //
}

//________________________________________________________________________________________
- (BOOL) tileHasThumbnail : (NSUInteger) tileIndex
{
   assert(tileIndex < tiles.count && "tileHasThumbnail, parameter 'tileIndex' is out of bounds");

   //
   //
   //

   return NO;
}

//________________________________________________________________________________________
- (void) layoutTiles
{
   assert(tiles.count <= 3 && "layoutTiles, unexpected number of tiles");
   //Depending on orientation and the pageRange, layout the slides.
   CGRect frame = self.frame;
   frame.origin = CGPoint();
   
   if (tiles.count == 1) {
      UIView * const tile = (UIView *)tiles[0];
      tile.frame = frame;
      [tile setNeedsDisplay];
      return;
   }
   
   if (frame.size.width > frame.size.height) {
      if (tiles.count == 2) {
         ((UIView *)tiles[0]).frame = CGRectMake(0.f, 0.f, frame.size.width / 2, frame.size.height);
         ((UIView *)tiles[1]).frame = CGRectMake(frame.size.width / 2, 0.f, frame.size.width / 2, frame.size.height);
      } else {
         ((UIView *)tiles[0]).frame = CGRectMake(0.f, 0.f, frame.size.width * 0.6f, frame.size.height);
         ((UIView *)tiles[1]).frame = CGRectMake(frame.size.width * 0.6, 0.f, frame.size.width * 0.4f, frame.size.height * 0.5f);
         ((UIView *)tiles[2]).frame = CGRectMake(frame.size.width * 0.6, frame.size.height * 0.5f, frame.size.width * 0.4f, frame.size.height * 0.5f);
      }
   } else {
      if (tiles.count == 2) {
         ((UIView *)tiles[0]).frame = CGRectMake(0.f, 0.f, frame.size.width, frame.size.height / 2);
         ((UIView *)tiles[1]).frame = CGRectMake(0.f, frame.size.height / 2, frame.size.width, frame.size.height / 2);
      } else {
         ((UIView *)tiles[0]).frame = CGRectMake(0.f, 0.f, frame.size.width, frame.size.height * 0.6f);
         ((UIView *)tiles[1]).frame = CGRectMake(0.f, frame.size.height * 0.6f, frame.size.width / 2, frame.size.height * 0.4f);
         ((UIView *)tiles[2]).frame = CGRectMake(frame.size.width / 2, frame.size.height * 0.6f, frame.size.width / 2, frame.size.height * 0.4f);
      }
   }
   
   for (BulletinIssueTileView *tile in tiles)
      [tile setNeedsDisplay];
}

//Animations:
//________________________________________________________________________________________
- (void) explodeTiles : (UIInterfaceOrientation) orientation
{
   assert(tiles.count <= 3 && "explodeTiles, unexpected number of tiles");
   
   if (tiles.count == 1)//No animation for this case, since tile occupies the whole page.
      return;

   const CGPoint pageCenter = self.center;

   for (BulletinIssueTileView *tile in tiles) {
      CGPoint tileCenter = tile.center;
      tileCenter.x += tileShift * (tileCenter.x - pageCenter.x);
      tileCenter.y += tileShift * (tileCenter.y - pageCenter.y);
      tile.center = tileCenter;
   }
}

//________________________________________________________________________________________
- (void) collectTilesAnimatedForOrientation : (UIInterfaceOrientation) orientation from : (CFTimeInterval) start withDuration : (CFTimeInterval) duration
{
  if (tiles.count == 1)
      return;

   const CGPoint pageCenter = self.layer.position;

   NSUInteger index = 0;
   for (BulletinIssueTileView *tile in tiles) {
      const CGPoint tileCenter = tile.layer.position;

      const CGPoint endPoint = CGPointMake((tileCenter.x + tileShift * pageCenter.x) / (1.f + tileShift),
                                           (tileCenter.y + tileShift * pageCenter.y) / (1.f + tileShift));

      CABasicAnimation * const animation = [CABasicAnimation animationWithKeyPath : @"position"];
      animation.fromValue = [NSValue valueWithCGPoint : tileCenter];
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
