#import <algorithm>
#import <cassert>

#import <QuartzCore/QuartzCore.h>
#import <CoreData/CoreData.h>

#import "FeedItemTileView.h"
#import "FeedPageView.h"

const NSUInteger shiftPart = 2;
const NSUInteger tilesOnPage = 4;

@implementation FeedPageView {
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
- (NSUInteger) setPageItems : (NSArray *) feedItems startingFrom : (NSUInteger) index
{
   assert(feedItems != nil && "setPageItems:startingFrom:, parameter 'feedItems' is nil");
   assert(index < feedItems.count && "setPageItems:startingFrom:, parameter 'index' is out of range");

   if (tiles) {
      for (FeedItemTileView *v in tiles)
         [v removeFromSuperview];
      [tiles removeAllObjects];
   } else
      tiles = [[NSMutableArray alloc] init];

   const NSUInteger endOfRange = std::min(feedItems.count, index + tilesOnPage);

   for (NSUInteger i = index; i < endOfRange; ++i) {
      FeedItemTileView *newTile = [[FeedItemTileView alloc] initWithFrame : CGRect()];
      [newTile setTileData : (MWFeedItem *)feedItems[i]];
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
   assert(thumbnailImage != nil && "setThumbnail:forTile, parameter 'thumbnailImage' is nil");
   assert(tileIndex < tiles.count && "setThumbnail:forTile, parameter 'tileIndex' is out of range");
   
   FeedItemTileView * const tile = (FeedItemTileView *)tiles[tileIndex];
   [tile setTileThumbnail : thumbnailImage doLayout : layout];
}

//________________________________________________________________________________________
- (BOOL) tileHasThumbnail : (NSUInteger) tileIndex
{
   assert(tileIndex < tiles.count && "tileHasThumbnail, parameter 'tileIndex' is out of bounds");
   
   return [(FeedItemTileView *)tiles[tileIndex] hasThumbnail];
}

//________________________________________________________________________________________
- (void) layoutTiles
{
   if (!tiles.count)
      return;

   //Layout tiles
   const CGRect frame = self.frame;
   //We always place 4 tiles on the page (if we have 4).

   //Hehe, can I, actually, use this to identify landscape orientation???
   const NSUInteger nItemsPerRow = 2;
   const NSUInteger nRows = 2;
   const CGFloat width = frame.size.width / nItemsPerRow;
   const CGFloat height = frame.size.height / nRows;
   
   NSUInteger index = 0;
   for (FeedItemTileView *tile in tiles) {
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

   const NSUInteger nItemsPerRow = 2;
   const NSUInteger nRows = 2;

   const CGFloat width = self.frame.size.width / nItemsPerRow;
   const CGFloat height = self.frame.size.height / nRows;

   NSUInteger index = 0;
   for (FeedItemTileView *tile in tiles) {
      const NSUInteger col = index % nItemsPerRow;
      const NSUInteger row = index / nItemsPerRow;
      CGFloat x = col * width;
      CGFloat y = row * height;
      CGRect frame = {};
      frame.size.width = width - 4;
      frame.size.height = height - 4;
      
      if (!col)
         x -= width / shiftPart;
      else if (col + 1 == nItemsPerRow)
         x += width / shiftPart;

      if (!row)
         y -= height / shiftPart;
      else if (row + 1 == nRows)
         y += height / shiftPart;
      
      frame.origin = CGPointMake(x, y);
      tile.frame = frame;
      tile.layer.frame = frame;
      [tile layoutTile];
      ++index;
   }
}

//________________________________________________________________________________________
- (void) collectTilesAnimatedForOrientation : (UIInterfaceOrientation) orientation from : (CFTimeInterval) start withDuration : (CFTimeInterval) duration
{
#pragma unused(orientation)

   const NSUInteger nItemsPerRow = 2;
   const NSUInteger nRows = 2;

   const CGFloat width = self.frame.size.width / nItemsPerRow;
   const CGFloat height = self.frame.size.height / nRows;

   NSUInteger index = 0;
   for (FeedItemTileView *tile in tiles) {
      const NSUInteger col = index % nItemsPerRow;
      const NSUInteger row = index / nItemsPerRow;

      const CGPoint startPoint = tile.layer.position;
      CGPoint endPoint = startPoint;
      
      if (!col)
         endPoint.x += width / shiftPart;
      else if (col + 1 == nItemsPerRow)
         endPoint.x -= width / shiftPart;

      if (!row)
         endPoint.y += height / shiftPart;
      else if (row + 1 == nRows)
         endPoint.y -= height / shiftPart;
      
      CABasicAnimation * const animation = [CABasicAnimation animationWithKeyPath : @"position"];
      animation.fromValue = [NSValue valueWithCGPoint : startPoint];
      animation.toValue = [NSValue valueWithCGPoint : endPoint];
      animation.beginTime = start;
      [animation setTimingFunction : [CAMediaTimingFunction functionWithControlPoints : 0.6f : 1.5f : 0.8f : 0.8f]];

      animation.duration = duration;
      [tile.layer addAnimation : animation forKey : [NSString stringWithFormat : @"bounce%lu", (unsigned long)index]];
      tile.layer.position = endPoint;
      //
      ++index;
   }
}

@end
