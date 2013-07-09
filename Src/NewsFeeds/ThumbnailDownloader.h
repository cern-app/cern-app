#import <Foundation/Foundation.h>

#import "ImageDownloader.h"

//With my new flipboard animation I have to update animation frames in a
//FlipView object as soon as thumbnails loaded. But I can not do it
//after a next thumbnail was loaded - this means too much work - update a lot
//of CALayers for every thumbnail downloaded on a page. Instead, I have ThubmnailDownloader
//class, it creates required ImageDownloader (per-thumbnail) and reports
//to its delegate when all thumbnails in a range were loaded (and at this
//point expensive update operation can be done once).

@class ThumbnailDownloader;

@protocol ThumbnailDownloaderDelegate<NSObject>

@required
- (void) thumbnailsDownloadDidFihish : (ThumbnailDownloader *) downloader;

@end


@interface ThumbnailDownloader : NSObject<ImageDownloaderDelegate>

//'items' are pairs [NSIndexPath *, NSString *]
//sizeLimit - imageData.length in bytes, 0 means no limit.
- (id) initWithItems : (NSArray *) items sizeLimit : (NSUInteger) sizeLimit;
//sizeLimit - imageData.length in bytes, 0 means no limit; dimension - width/height for resulting thumbnail,
//only one dimension, since thumbnail is ~square (though resulting images are not guaranteed to be square).
- (id) initWithItems : (NSArray *) items sizeLimit : (NSUInteger) sizeLimit downscaleToSize : (CGFloat) dimension;

- (BOOL) startDownload;
- (void) cancelDownload;

- (BOOL) containsIndexPath : (NSIndexPath *) path;

@property (nonatomic) NSUInteger pageNumber;
@property (nonatomic, readonly) NSMutableDictionary *imageDownloaders;
@property (nonatomic) __weak NSObject<ThumbnailDownloaderDelegate> *delegate;

@end
