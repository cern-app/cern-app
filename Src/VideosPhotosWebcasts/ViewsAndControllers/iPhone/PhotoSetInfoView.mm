//
//  PhotoSetInfoView.m
//  CERN
//
//  Created by Timur Pocheptsov on 1/16/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import "PhotoSetInfoView.h"

@implementation PhotoSetInfoView

@synthesize descriptionLabel;

//________________________________________________________________________________________
- (id) initWithFrame : (CGRect) frame
{
   if (self = [super initWithFrame : frame]) {
      //
      descriptionLabel = [[UILabel alloc] initWithFrame : CGRect()];
   }

   return self;
}

@end
