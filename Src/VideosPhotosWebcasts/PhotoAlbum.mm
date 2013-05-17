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

using CernAPP::ResourceTypeThumbnail;

@implementation PhotoAlbum {
   NSMutableArray *albumData;
   BOOL stackedMode;
   NSUInteger stackIndex;
   
   NSMutableDictionary *downloaders;
   __weak PhotoAlbum *photoAlbum;
   __weak NSObject<ImageDownloaderDelegate> *delegate;   
}

@synthesize title, sectionIndex, delegate;

//________________________________________________________________________________________
- (id) init
{
   if (self = [super init]) {
      albumData = [[NSMutableArray alloc] init];
      stackedMode = NO;
      stackIndex = 0;
      
      downloaders = [[NSMutableDictionary alloc] init];
      photoAlbum = nil;
      delegate = nil;      
   }

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

//________________________________________________________________________________________
- (void) loadFirstThumbnail
{
   if (downloaders.count)
      return;
   
   if (!albumData.count)
      return;

   stackedMode = YES;
   stackIndex = 0;

   [self loadNextThumbnail];
}

//________________________________________________________________________________________
- (void) loadNextThumbnail
{
   assert(stackIndex < albumData.count && "loadNextThumbnail, stackIndex is out of bounds");
   
   ImageDownloader * const downloader = [[ImageDownloader alloc] initWithURL :
                                         [self getImageURLWithIndex : stackIndex forType : ResourceTypeThumbnail]];
   NSIndexPath * const key = [NSIndexPath indexPathForRow : stackIndex inSection : sectionIndex];
   downloader.indexPathInTableView = key;
   [downloaders setObject : downloader forKey : key];
   [downloader startDownload];
}

//________________________________________________________________________________________
- (void) loadThumbnails
{
   //Load everything here.
}

#pragma mark - ImageDownloader delegate.

//________________________________________________________________________________________
- (void) imageDidLoad : (NSIndexPath *) indexPath
{
   assert(indexPath != nil && "imageDidLoad:, parameter 'indexPath' is nil");
   assert(delegate != nil && "imageDidLoad:, delegate is nil");//No reason to download anything without the delegate.
   
   ImageDownloader * const downloader = (ImageDownloader *)downloaders[indexPath];
   assert(downloader != nil && "imageDidLoad:, no downloader found for indexPath");
   if (downloader.image)
      [self setThumbnailImage : downloader.image withIndex : indexPath.row];
   [delegate imageDidLoad : indexPath];
   
   [downloaders removeObjectForKey : indexPath];
}

//________________________________________________________________________________________
- (void) imageDownloadFailed : (NSIndexPath *) indexPath
{
   assert(indexPath != nil && "imageDownloadFailed:, parameter 'indexPath' is nil");
   assert(delegate != nil && "imageDownloadFailed:, delegate is nil");//No reason to download anything without the delegate.
   assert(downloaders[indexPath] != nil && "imageDownloadFailed:, no downloader found for indexPath");
   
   [downloaders removeObjectForKey : indexPath];
   
   if (stackedMode) {
      if (stackIndex + 1 < albumData.count) {//Try again!
         ++stackIndex;
         [self loadNextThumbnail];
      } else {
         [delegate imageDownloadFailed : indexPath];//We inform only at this point - all failed.
      }
   }
}

@end
