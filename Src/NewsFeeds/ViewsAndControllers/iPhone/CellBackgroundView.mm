//
//  CellBackgroundView.mm
//  CERN
//
//  Created by Timur Pocheptsov on 1/17/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import "CellBackgroundView.h"
#import "GUIHelpers.h"

@implementation CellBackgroundView

//________________________________________________________________________________________
- (void) drawRect : (CGRect) rect
{
   // draw a rounded rect bezier path filled with blue
   
   CGContextRef ctx = UIGraphicsGetCurrentContext();

   //Push.
   CGContextSaveGState(ctx);

   CGContextSetRGBFillColor(ctx, 1.f, 1.f, 1.f, 1.f);
   CGContextFillRect(ctx, rect);
   
   //Draw a gray line.
   CGContextSetLineWidth(ctx, 2.f);
   CGContextSetRGBStrokeColor(ctx, 224 / 255.f, 224 / 255.f, 224 / 255.f, 1.f);
   CGContextMoveToPoint(ctx, 0.f, rect.size.height);
   CGContextAddLineToPoint(ctx, rect.size.width, rect.size.height);
   CGContextStrokePath(ctx);

   //Pop.
   CGContextRestoreGState(ctx);   
}

@end
