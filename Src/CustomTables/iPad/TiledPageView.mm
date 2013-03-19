//
//  TiledPageView.m
//  CERN
//
//  Created by Timur Pocheptsov on 3/18/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <cassert>

#import "TiledPageView.h"
#import "TileView.h"

@implementation TiledPageView {
   NSMutableArray *tiles;
}

//________________________________________________________________________________________
- (id) initWithFrame : (CGRect) frame
{
   if (self = [super initWithFrame : frame]) {
      //
   }

   return self;
}

//________________________________________________________________________________________
- (void) setPageItems : (NSArray *) feedItems startingFrom : (NSUInteger) index
{
//   assert(feedItems != nil && "setPageItems:startingFrom:, parameter 'feedItems' is nil");
//   assert(index < feedItems.count && "setPageItems:startingFrom:, parameter 'index' is out of range");

   tiles = [[NSMutableArray alloc] init];

   /////////////////////
   //Test only.
   for (NSUInteger i = 0; i < 6; ++i) {
      TileView *newTile = [[TileView alloc] initWithFrame : CGRect()];
      [newTile setTileData : nil];
      [tiles addObject : newTile];
      [self addSubview : newTile];
   }
   //Test only.
   /////////////////////
}

//________________________________________________________________________________________
- (void) layoutTiles
{
   if (!tiles.count)
      return;

   //Layout tiles
   const CGRect frame = self.frame;
   //We always place 6 tiles on the page (if we have 6).

   //Hehe, can I, actually, use this to identify landscape orientation???
   const NSUInteger nItemsPerRow = frame.size.width > frame.size.height ? 3 : 2;
   const NSUInteger nRows = nItemsPerRow == 3 ? 2 : 3;
   const CGFloat width = frame.size.width / nItemsPerRow;
   const CGFloat height = frame.size.height / nRows;
   
   NSUInteger index = 0;
   for (TileView *tile in tiles) {
      const CGFloat x = (index % nItemsPerRow) * width + 2.f;
      const CGFloat y = (index / nItemsPerRow) * height + 2.f;
      const CGRect frame = CGRectMake(x, y, width - 4.f, height - 4.f);

      tile.frame = frame;
      
      ++index;
   }
}

/*
//________________________________________________________________________________________
- (void) layoutSubviews
{
   if (!tiles.count)
      return;

   //Layout tiles
   const CGRect frame = self.frame;
   //We always place 6 tiles on the page (if we have 6).

   //Hehe, can I, actually, use this to identify landscape orientation???
   const NSUInteger nItemsPerRow = frame.size.width > frame.size.height ? 3 : 2;
   const NSUInteger nRows = nItemsPerRow == 3 ? 2 : 3;
   const CGFloat width = frame.size.width / nItemsPerRow;
   const CGFloat height = frame.size.height / nRows;
   
   NSUInteger index = 0;
   for (TileView *tile in tiles) {
      const CGFloat x = (index % nItemsPerRow) * width + 2.f;
      const CGFloat y = (index / nItemsPerRow) * height + 2.f;
      const CGRect frame = CGRectMake(x, y, width - 4.f, height - 4.f);

      tile.frame = frame;
      ++index;
   }
}*/

//________________________________________________________________________________________
- (void) startTileAnimationTo : (UIInterfaceOrientation) orientation
{
   const NSUInteger nItemsPerRow = UIInterfaceOrientationIsLandscape(orientation) ? 3 : 2;
   const NSUInteger nRows = nItemsPerRow == 3 ? 2 : 3;

   const CGFloat width = self.frame.size.width / nItemsPerRow;
   const CGFloat height = self.frame.size.height / nRows;

   NSUInteger index = 0;
   for (TileView *tile in tiles) {
      const NSUInteger col = index % nItemsPerRow;
      const NSUInteger row = index / nItemsPerRow;
      CGFloat x = col * width;
      CGFloat y = row * height;
      CGRect frame = tile.frame;
      
      if (!col)
         x -= width / 2;
      else if (col + 1 == nItemsPerRow)
         x += width / 2;
     // else if (UIInterfaceOrientationIsLandscape(orientation))
     //    x = width / 3.f;

      if (!row)
         y -= height / 2;
      else if (row + 1 == nRows)
         y += height / 2;
     // else if (UIInterfaceOrientationIsLandscape(orientation))
     //    y = height / 2.f;
      
      frame.origin = CGPointMake(x, y);
      tile.frame = frame;
      ++index;
   }
}

@end
