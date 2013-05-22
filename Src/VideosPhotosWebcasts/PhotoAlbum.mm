//
//  PhotoAlbum.m
//  CERN
//
//  Created by Timur Pocheptsov on 5/17/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <cassert>

#import "PhotoAlbum.h"

namespace CernAPP {

NSString * const ResourceTypeThumbnail = @"jpgIcon";
NSString * const ResourceTypeThumbnailImage = @"Thumbnail";
NSString * const ResourceTypeImageForPhotoBrowserIPAD = @"jpgA4";

}

using CernAPP::ResourceTypeThumbnail;
using CernAPP::ResourceTypeThumbnailImage;

@implementation PhotoAlbum {
   NSMutableArray *albumData;
}

@synthesize title;

//________________________________________________________________________________________
- (id) init
{
   if (self = [super init])
      albumData = [[NSMutableArray alloc] init];

   return self;
}

//________________________________________________________________________________________
- (void) addImageData : (NSDictionary *) dict
{
   assert(dict != nil && "addImageRecord:, parameter 'dict' is nil");

   id copy = [dict mutableCopy];
   [albumData addObject : copy];
}

//________________________________________________________________________________________
- (UIImage *) getThumbnailImageForIndex : (NSUInteger) index
{
   assert(index < albumData.count && "getThumbnailImageForIndex, parameter 'index' is out of bounds");
   
   NSDictionary * const imageData = (NSDictionary *)albumData[index];
   return (UIImage *)imageData[ResourceTypeThumbnailImage];
}

//________________________________________________________________________________________
- (void) setThumbnailImage : (UIImage *) image withIndex : (NSUInteger) index
{
   assert(image != nil && "setThumbnailImage:withIndex:, parameter 'image' is nil");
   assert(index < albumData.count && "setThumbnailImage:withIndex:, parameter 'index' is out of bounds");
   
   NSMutableDictionary * const imageDict = (NSMutableDictionary *)albumData[index];
   [imageDict setObject : image forKey : ResourceTypeThumbnailImage];
}

//________________________________________________________________________________________
- (NSURL *) getImageURLWithIndex : (NSUInteger) index forType : (NSString *) type
{
   assert(index < albumData.count && "getImageURLWithIndex:forType:, parameter 'index' is out of bounds");
   assert(type != nil && "getImageURLWithIndex:forType:, parameter 'type' is nil");
   
   NSDictionary * const imageData = (NSDictionary *)albumData[index];
   assert(imageData[type] != nil && "getImageURLWithIndex:forType:, no url for resource type found");
   
   return (NSURL *)imageData[type];
}

//________________________________________________________________________________________
- (NSUInteger) nImages
{
   return albumData.count;
}

@end
