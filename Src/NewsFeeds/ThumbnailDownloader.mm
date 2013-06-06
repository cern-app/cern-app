#import <cassert>

#import "ThumbnailDownloader.h"
#import "KeyVal.h"

namespace {

enum class ThumbnailDownloadStage : unsigned char {
   none,
   dataDownload,
   imageCreation
};

}

@implementation ThumbnailDownloader {
   NSMutableDictionary *thumbnailsData;//NSMutableData
   NSMutableArray *thumbnailImages;//UIImage
   
   NSUInteger nCompleted;
   ThumbnailDownloadStage stage;
   
   NSOperationQueue *opQueue;
   NSInvocationOperation *imageCreateOp;
   BOOL cancelled;
   
   CGFloat downscaledSize;
}

@synthesize pageNumber, imageDownloaders, delegate;

//________________________________________________________________________________________
- (id) initWithItems : (NSArray *) items sizeLimit : (NSUInteger) sizeLimit
{
   assert(items.count != 0 && "initWithItems:sizeLimit:, parameter 'items' is either nil or is empty");

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
         //
         downloader.dataSizeLimit = sizeLimit;
         //
         downloader.indexPathInTableView = indexPath;
         downloader.delegate = self;
         [imageDownloaders setObject : downloader forKey : indexPath];
      }
      
      nCompleted = 0;
      stage = ThumbnailDownloadStage::none;
      
      opQueue = nil;
      imageCreateOp = nil;
      
      downscaledSize = 0.f;
   }
   
   return self;
}

//________________________________________________________________________________________
- (id) initWithItems : (NSArray *) items sizeLimit : (NSUInteger) sizeLimit downscaleToSize : (CGFloat) dimension
{
   assert(items != nil && "initWithItems:sizeLimit:downscaleToSize:, parameter 'items' is nil");
   assert(dimension >= 0.f && "initWithItems:sizeLimit:downscaleToSize:, parameter 'maxDim' is negative");

   if (self = [self initWithItems : items sizeLimit : sizeLimit]) {
      downscaledSize = dimension;
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

   cancelled = NO;

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
   }
   
   cancelled = YES;
   nCompleted = 0;
   stage = ThumbnailDownloadStage::none;
}

//________________________________________________________________________________________
- (BOOL) containsIndexPath : (NSIndexPath *) indexPath
{
   assert(indexPath != nil && "containsIndexPath:, parameter 'indexPath' is nil");
   return imageDownloaders[indexPath] != nil;
}

#pragma mark - ImageDownloader delegate.

//________________________________________________________________________________________
- (void) imageDidLoad : (NSIndexPath *) indexPath
{
   assert(cancelled == NO && "imageDidLoad:, operation was cancelled already");

   assert(indexPath != nil && "imageDidLoad:, parameter 'indexPath' is nil");
   assert(imageDownloaders[indexPath] != nil && "imageDidLoad:, unknown index path");
   assert(stage == ThumbnailDownloadStage::dataDownload &&
          "imageDidLoad:, wrong stage");
   assert(nCompleted < imageDownloaders.count &&
          "imageDidLoad:, all images loaded");

   if (++nCompleted == imageDownloaders.count)
      [self createUIImages];
}

//________________________________________________________________________________________
- (void) imageDownloadFailed : (NSIndexPath *) indexPath
{
   assert(cancelled == NO && "imageDownloadFailed:, operation was cancelled already");

   assert(indexPath != nil && "imageDownloadFailed:, parameter 'indexPath' is nil");
   assert(imageDownloaders[indexPath] != nil && "imageDownloadFailed:, unknown index path");
   assert(stage == ThumbnailDownloadStage::dataDownload &&
          "imageDownloadFailed:, wrong stage");
   assert(nCompleted < imageDownloaders.count &&
          "imageDownloadFailed:, all images loaded");

   if (++nCompleted == imageDownloaders.count)
      [self createUIImages];
}

//________________________________________________________________________________________
- (void) createUIImages
{
   //Right now we do not have real thumbnails, instead, we can have a huge images (like 2000x2000),
   //if I create a bunch of such images on a main GUI thread, it's "blocked" and the app is non-interactive.
   //So I want to use a background thread for these operations.
   assert(stage == ThumbnailDownloadStage::dataDownload && "createUIImages, wrong stage");
   assert(cancelled == NO && "createUIImages, operation was cancelled");

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
   
   @autoreleasepool {   
      NSEnumerator * const keyEnumerator = [imageDownloaders keyEnumerator];
      for (id key in keyEnumerator) {
         if (imageCreateOp.isCancelled) {
            imageCreateOp = nil;
            return;
         }
         ImageDownloader * const downloader = (ImageDownloader *)imageDownloaders[key];
         if (downscaledSize > 0.f)
            [downloader createThumbnailImageScaledTo : downscaledSize];
         else
            [downloader createUIImage];
      }
   }
   
   [self performSelectorOnMainThread : @selector(informDelegate) withObject : nil waitUntilDone : NO];
}

//________________________________________________________________________________________
- (void) informDelegate
{
   //This function is executed on a main GUI thread, cancelDownload (cancelled = YES)
   //is also called on a main GUI thread (and the order is guaranteed), so it's ok
   //to check cancelled.
   
   imageCreateOp = nil;
   
   if (delegate && !cancelled)
      [delegate thumbnailsDownloadDidFihish : self];
}

@end
