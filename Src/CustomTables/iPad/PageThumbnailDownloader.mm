//
//  PageDataDownloader.m
//  CERN
//
//  Created by Timur Pocheptsov on 5/6/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <cassert>

#import "PageThumbnailDownloader.h"
#import "KeyVal.h"

namespace {

enum class ThumbnailDownloadStage : unsigned char {
   none,
   dataDownload,
   imageCreation
};

}

@implementation PageThumbnailDownloader {
   NSMutableDictionary *thumbnailsData;//NSMutableData
   NSMutableArray *thumbnailImages;//UIImage
   
   NSUInteger nCompleted;
   ThumbnailDownloadStage stage;
   
   NSOperationQueue *opQueue;
   NSInvocationOperation *imageCreateOp;
}

@synthesize pageNumber, imageDownloaders, delegate;

//________________________________________________________________________________________
- (id) initWithItems : (NSArray *) items
{
   assert(items.count != 0 && "initWithItems:, parameter 'items' is either nil or is empty");

   if (self = [super init]) {
      imageDownloaders = [[NSMutableDictionary alloc] init];
   
      for (id itemBase in items) {
         assert([itemBase isKindOfClass : [KeyVal class]] &&
                "initWithItems:, unknown item type, KeyVal expected");
         
         KeyVal * const item = (KeyVal *)itemBase;
         assert([item.key isKindOfClass : [NSIndexPath class]] &&
                "initWithItems:, item.key is invalid");
         assert([item.val isKindOfClass : [NSString class]] &&
                "initWithItems:, item.val is invalid");
         
         
         NSIndexPath * const indexPath = (NSIndexPath *)item.key;
         
         ImageDownloader * const downloader = [[ImageDownloader alloc] initWithURLString : (NSString *)item.val];
         if (!downloader) {
            NSLog(@"initWithItems:, no downloader for %@", (NSString *)item.val);
            continue;
         }

         downloader.indexPathInTableView = indexPath;
         downloader.delegate = self;
         [imageDownloaders setObject : downloader forKey : indexPath];
      }
      
      nCompleted = 0;
      stage = ThumbnailDownloadStage::none;
      
      opQueue = nil;
      imageCreateOp = nil;
   }
   
   return self;
}

//________________________________________________________________________________________
- (BOOL) startDownload
{
   if (stage != ThumbnailDownloadStage::none)
      return NO;

   if (!imageDownloaders.count)
      return NO;

   stage = ThumbnailDownloadStage::dataDownload;
   NSEnumerator * const keyEnumerator = [imageDownloaders keyEnumerator];
   nCompleted = 0;
   for (id key in keyEnumerator) {
      ImageDownloader * const downloader = (ImageDownloader *)imageDownloaders[key];
      [downloader cancelDownload];//if it was started already
      [downloader startDownload : YES];//Do not create the final UIImage object.
   }
   
   return YES;
}

//________________________________________________________________________________________
- (void) cancelDownload
{
   if (stage == ThumbnailDownloadStage::dataDownload) {
      NSEnumerator * const keyEnumerator = [imageDownloaders keyEnumerator];
      for (id key in keyEnumerator) {
         ImageDownloader * const downloader = (ImageDownloader *)imageDownloaders[key];
         [downloader cancelDownload];
      }
   } else if (stage == ThumbnailDownloadStage::imageCreation) {
      //Cancel the background operation.
      [imageCreateOp cancel];
      imageCreateOp = nil;
      opQueue = nil;
   }
   
   nCompleted = 0;
   stage = ThumbnailDownloadStage::none;
}

#pragma mark - ImageDownloader delegate.

//________________________________________________________________________________________
- (void) imageDidLoad : (NSIndexPath *) indexPath
{
   assert(indexPath != nil && "imageDidLoad, parameter 'indexPath' is nil");
   assert(imageDownloaders[indexPath] != nil && "imageDidLoad:, unknown index path");
   assert(stage == ThumbnailDownloadStage::dataDownload &&
          "imageDidLoad:, wrong stage");
   assert(nCompleted < imageDownloaders.count &&
          "imageDidLoad:, all images loaded");

   if (nCompleted + 1 == imageDownloaders.count) {
      //Create the corresponding UIImage objects.
      [self createUIImages];
   } else
      ++nCompleted;
}

//________________________________________________________________________________________
- (void) imageDownloadFailed : (NSIndexPath *) indexPath
{
   assert(indexPath != nil && "imageDownloadFailed:, parameter 'indexPath' is nil");
   assert(imageDownloaders[indexPath] != nil && "imageDownloadFailed:, unknown index path");
   assert(stage == ThumbnailDownloadStage::dataDownload &&
          "imageDownloadFailed:, wrong stage");
   assert(nCompleted < imageDownloaders.count &&
          "imageDownloadFailed:, all images loaded");

   if (nCompleted + 1 == imageDownloaders.count) {
      ++nCompleted;
      [self createUIImages];
   } else
      ++nCompleted;
}

//________________________________________________________________________________________
- (void) createUIImages
{
   //Right now we do not have real thumbnails, instead, we can have a huge images (like 2000x2000),
   //if I create a bunch of such images on a main GUI thread, it's "blocked" and the app is non-interactive.
   //So I want to use a background thread for these operations.
   assert(stage == ThumbnailDownloadStage::dataDownload && "createImage, wrong stage");
   
   stage = ThumbnailDownloadStage::imageCreation;
   nCompleted = 0;
   
   opQueue = [[NSOperationQueue alloc] init];
   imageCreateOp = [[NSInvocationOperation alloc] initWithTarget : self selector : @selector(createUIImagesAux) object : nil];
   [opQueue addOperation : imageCreateOp];
}

//________________________________________________________________________________________
- (void) createUIImagesAux
{
   assert(stage == ThumbnailDownloadStage::imageCreation && "createUIImagesAux, wrong stage");
   
   NSEnumerator * const keyEnumerator = [imageDownloaders keyEnumerator];
   for (id key in keyEnumerator) {
      if (imageCreateOp.isCancelled)
         return;
      ImageDownloader * const downloader = (ImageDownloader *)imageDownloaders[key];
      [downloader createUIImage];
   }
   
   [self performSelectorOnMainThread : @selector(informDelegate) withObject : nil waitUntilDone : NO];
}

//________________________________________________________________________________________
- (void) informDelegate
{
   if (delegate)
      [delegate thumbnailsDownloadDidFihish : self];
}

@end
