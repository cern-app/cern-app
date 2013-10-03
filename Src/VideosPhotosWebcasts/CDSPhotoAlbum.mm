//
//  CDSPhotoAlbum.m
//  CERN
//
//  Created by Timur Pocheptsov on 10/3/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import "CDSPhotoAlbum.h"

namespace CernAPP {

NSString * const thumbnailImageUrl = @"thumbnailUrl";
NSString * const thumbnailImage = @"thumbnailImage";
NSString * const iPhoneImageUrl = @"iPhoneUrl";
NSString * const iPadImageUrl = @"iPadUrl";

}

@implementation CDSPhotoAlbum {
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
   return (UIImage *)imageData[CernAPP::thumbnailImage];
}

//________________________________________________________________________________________
- (void) setThumbnailImage : (UIImage *) image withIndex : (NSUInteger) index
{
   assert(image != nil && "setThumbnailImage:withIndex:, parameter 'image' is nil");
   assert(index < albumData.count && "setThumbnailImage:withIndex:, parameter 'index' is out of bounds");
   
   NSMutableDictionary * const imageDict = (NSMutableDictionary *)albumData[index];
   [imageDict setObject : image forKey : CernAPP::thumbnailImage];
}

//________________________________________________________________________________________
- (NSURL *) getImageURLWithIndex : (NSUInteger) index urlType : (NSString *) type
{
   assert(index < albumData.count && "getImageURLWithIndex:urlType:, parameter 'index' is out of bounds");
   assert(type != nil && "getImageURLWithIndex:urlType:, parameter 'size' is nil");
   
   NSDictionary * const imageData = (NSDictionary *)albumData[index];
   assert(imageData[type] != nil && "getImageURLWithIndex:urlType:, no url for resource type found");
   
   return (NSURL *)imageData[type];
}

//________________________________________________________________________________________
- (NSUInteger) nImages
{
   return albumData.count;
}

@end
