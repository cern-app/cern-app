#import <Foundation/Foundation.h>

#import "ImageDownloader.h"

//
//With my new flipboard animation I have to update animation frames in a
//FlipView object as soon as thumbnails loaded. But I can not do it
//after a next thumbnail was loaded - this means to many work - update
//after every thumbnail on a page. Instead, I have PageThubmnailDownloader
//class, it creates required ImageDownloader (per-thumbnail) and reports
//to its delegate when all thumbnails on a page were loaded (and at this
//point expensive update operation can be done once).

@class PageThumbnailDownloader;

@protocol PageThumbnailDownloaderDelegate<NSObject>

@required
- (void) thumbnailsDownloadDidFihish : (PageThumbnailDownloader *) downloader;

@end


@interface PageThumbnailDownloader : NSObject<ImageDownloaderDelegate>

//'items' are pairs [NSIndexPath *, NSString *]
//sizeLimit == 0 -> not limitation.
- (id) initWithItems : (NSArray *) items sizeLimit : (NSUInteger) sizeLimit;
- (id) initWithItems : (NSArray *) items sizeLimit : (NSUInteger) sizeLimit downscaleToSize : (CGFloat) maxDim;

- (BOOL) startDownload;
- (void) cancelDownload;

- (BOOL) containsIndexPath : (NSIndexPath *) path;

@property (nonatomic) NSUInteger pageNumber;
@property (nonatomic, readonly) NSMutableDictionary *imageDownloaders;
@property (nonatomic) __weak NSObject<PageThumbnailDownloaderDelegate> *delegate;

@end
