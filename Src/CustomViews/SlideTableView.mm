//
//  SlideTableView.m
//  CERN
//
//  Created by Timur Pocheptsov on 9/23/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import "SlideTableView.h"

@implementation SlideTableView

//________________________________________________________________________________________
- (UIView *) hitTest : (CGPoint) point withEvent : (UIEvent *) event
{  
   //We have a scrollview in a slideview controller. To make it possible to open the menu
   //(slide a view) let's use 30/50 pixels at the left (on any page) as a 'dead' zone - scrollview
   //is inactive here and the underlaying view will have a touch (and slide).
   if (point.x >= 0) {
      const CGFloat margin = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone ? 30.f : 50.f;
      const CGFloat x = point.x - NSUInteger(point.x / self.frame.size.width) * self.frame.size.width;
      if (x > margin)
         return [super hitTest : point withEvent : event];
   }

   return nil;
}

@end
