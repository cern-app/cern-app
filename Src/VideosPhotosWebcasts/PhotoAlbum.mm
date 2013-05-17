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

extern NSString * const ResourceTypeThumbnail = @"Thumbnail";

}

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
   return (UIImage *)imageData[@"Thumbnail"];
}

//________________________________________________________________________________________
- (void) setThumbnailImage : (UIImage *) image withIndex : (NSUInteger) index
{
   assert(image != nil && "setThumbnailImage:withIndex:, parameter 'image' is nil");
   assert(index < albumData.count && "setThumbnailImage:withIndex:, parameter 'index' is out of bounds");
   
   NSMutableDictionary * const imageDict = (NSMutableDictionary *)albumData[index];
   [imageDict setObject : image forKey : @"Thumbnail"];
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

@implementation PhotoAlbumThumbnailDownloader {
   BOOL stackedMode;
   NSUInteger stackIndex;
   
   NSMutableDictionary *downloaders;
   __weak PhotoAlbum *photoAlbum;
   __weak NSObject<ImageDownloaderDelegate> *delegate;
}

//________________________________________________________________________________________
- (id) init
{
   if (self = [super init]) {
      stackedMode = NO;
      stackIndex = 0;
      
      downloaders = [[NSMutableDictionary alloc] init];
      photoAlbum = nil;
      delegate = nil;
   }
   
   return self;
}

//________________________________________________________________________________________
- (void) loadFirstThumbnailForAlbum : (PhotoAlbum *) album delegate : (NSObject<ImageDownloaderDelegate> *) aDelegate
{
   assert(album != nil && "loadFirstThumbnailForAlbum:delegate:, parameter 'album' is nil");
   assert(aDelegate != nil && "loadFirstThumbnailForAlbum:delegate:, parameter 'aDelegate' is nil");
   
   if (downloaders.count) {
      assert(0 && "loadFirstThumbnailForAlbum:delegate:, called while download is still active.");
      return;
   }
   
   if (!album.nImages) {
      assert(0 && "loadFirstThumbnailForAlbum:delegate:, invalid photo album");
      return;
   }

   stackedMode = YES;

   photoAlbum = album;
   delegate = aDelegate;
   
   //We just try to load the first image and do not touch the others - they are not visible in a stacked mode.
   
}

//________________________________________________________________________________________
- (void) loadThumbnailsForAlbum : (PhotoAlbum *) album delegate : (NSObject<ImageDownloaderDelegate> *) delegate
{

}

#pragma mark - ImageDownloader delegate.

//________________________________________________________________________________________
- (void) imageDidLoad : (NSIndexPath *) indexPath
{

}

//________________________________________________________________________________________
- (void) imageDownloadFailed : (NSIndexPath *) indexPath
{

}

@end

