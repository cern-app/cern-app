//
//  BulletinPageView.m
//  CERN
//
//  Created by Timur Pocheptsov on 4/11/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

#import "BulletinTableViewController.h"
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
   assert(index + pageRange.length <= items.count &&
          "setPageItems:startingFrom:, pageRange is out of bounds");

   //Items in the 'items' array are arrays with MWFeedItems sorted by the date.
   if (!tiles)
      tiles = [[NSMutableArray alloc] init];
   else {
      for (BulletinIssueTileView *tile in tiles)
         [tile removeFromSuperview];
      [tiles removeAllObjects];
   }
   
   assert(pageRange.length <= 3 && "setPageItems:startingFrom:, the page range > 3 is not supported");
   //A primitive attempt to make a tile's layout more interesting.
   //[0] == wideImageOnTop, [1] == squareImageOnLeft
   const BOOL tileHints[][2] = {{YES, YES}, {NO, NO}, {YES, YES}};
   
   pageRange = [BulletinPageView suggestRangeForward : items startingFrom : index];

   for (NSUInteger i = 0; i < pageRange.length; ++i, ++index) {
      //Using the array of MWFeedItems, find the issue's date and create a tile.
      //Create a tile.
      BulletinIssueTileView * const newTile = [[BulletinIssueTileView alloc] initWithFrame : CGRect()];
      //Set the image if any.
      //Set the text.
      assert([items[index] isKindOfClass:[NSArray class]] &&
             "setPageItems:startingFrom:, array element has a wrong type");
      [newTile setTileText : CernAPP::BulletinTitleForWeek((NSArray *)items[index])];
      
      newTile.wideImageOnTopHint = tileHints[i][0];
      newTile.squareImageOnLeftHint = tileHints[i][1];
      newTile.issueNumber = index;

      [self addSubview : newTile];
      [tiles addObject : newTile];
   }

   return pageRange.length;
}

//________________________________________________________________________________________
- (void) setThumbnail : (UIImage *) thumbnailImage forTile : (NSUInteger) tileIndex doLayout : (BOOL) layout
{
#pragma unused(layout)

   assert(thumbnailImage != nil && "setThumbnail:forTile:, parameter 'thumbnailImge' is nil");
   assert(tileIndex < tiles.count && "setThumbnail:forTile:, parameter 'tileIndex' is out of bounds");
   
   BulletinIssueTileView * const tile = (BulletinIssueTileView *)tiles[tileIndex];
   [tile setThumbnailImage : thumbnailImage];
}

//________________________________________________________________________________________
- (BOOL) tileHasThumbnail : (NSUInteger) tileIndex
{
   assert(tileIndex < tiles.count && "tileHasThumbnail, parameter 'tileIndex' is out of bounds");

   BulletinIssueTileView * const tile = (BulletinIssueTileView *)tiles[tileIndex];
   return [tile hasThumbnailImage];
}

//________________________________________________________________________________________
- (void) layoutTiles
{
   assert(tiles.count > 0 && tiles.count <= 3 && "layoutTiles, unexpected number of tiles on a page");
   //Depending on orientation and the pageRange, layout the slides.
   CGRect frame = self.frame;
   frame.origin = CGPoint();
   
   if (tiles.count == 1) {
      BulletinIssueTileView * const tile = (BulletinIssueTileView *)tiles[0];
      tile.frame = frame;
      [tile layoutContents];
      return;
   }
   
   if (frame.size.width > frame.size.height) {
      if (tiles.count == 2) {
         ((UIView *)tiles[0]).frame = CGRectMake(4.f, 4.f, frame.size.width / 2 - 8.f, frame.size.height - 8.f);
         ((UIView *)tiles[1]).frame = CGRectMake(frame.size.width / 2 + 4.f, 4.f, frame.size.width / 2 - 8.f, frame.size.height - 8.f);
      } else {
         ((UIView *)tiles[0]).frame = CGRectMake(4.f, 4.f, frame.size.width * 0.6f - 8.f, frame.size.height - 8.f);
         ((UIView *)tiles[1]).frame = CGRectMake(frame.size.width * 0.6 + 4.f, 4.f, frame.size.width * 0.4f - 8.f, frame.size.height * 0.5f - 8.f);
         ((UIView *)tiles[2]).frame = CGRectMake(frame.size.width * 0.6 + 4.f, frame.size.height * 0.5f + 4.f, frame.size.width * 0.4f - 8.f, frame.size.height * 0.5f - 8.f);
      }
   } else {
      if (tiles.count == 2) {
         ((UIView *)tiles[0]).frame = CGRectMake(4.f, 4.f, frame.size.width - 8.f, frame.size.height / 2 - 8.f);
         ((UIView *)tiles[1]).frame = CGRectMake(4.f, frame.size.height / 2 + 4.f, frame.size.width - 8.f, frame.size.height / 2 - 8.f);
      } else {
         ((UIView *)tiles[0]).frame = CGRectMake(4.f, 4.f, frame.size.width - 8.f, frame.size.height * 0.6f - 8.f);
         ((UIView *)tiles[1]).frame = CGRectMake(4.f, 4.f + frame.size.height * 0.6f, frame.size.width / 2 - 8.f, frame.size.height * 0.4f - 8.f);
         ((UIView *)tiles[2]).frame = CGRectMake(4.f + frame.size.width / 2, 4.f + frame.size.height * 0.6f, frame.size.width / 2 - 8.f, frame.size.height * 0.4f - 8.f);
      }
   }
   
   for (BulletinIssueTileView *tile in tiles)
      [tile layoutContents];
}

//Animations:
//________________________________________________________________________________________
- (void) explodeTiles : (UIInterfaceOrientation) orientation
{
   assert(tiles.count <= 3 && "explodeTiles, unexpected number of tiles");
   
   //TODO: test! is center always correct and can I always use it to do these calculations?
   //If not, it's easy (I think) to use view's frames to do the same job.
   
   if (tiles.count == 1)//No animation for this case, since tile occupies the whole page.
      return;

   const CGPoint pageCenter = self.center;

   for (BulletinIssueTileView *tile in tiles) {
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
  if (tiles.count == 1)
      return;

   //TODO: test! is center always correct and can I always use it to do these calculations?
   //If not, it's easy (I think) to use view's frames to do the same job.

   const CGPoint pageCenter = self.center;

   NSUInteger index = 0;
   for (BulletinIssueTileView *tile in tiles) {
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
