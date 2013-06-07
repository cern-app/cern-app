#import "PhotoAlbumCoverView.h"

@class MWFeedItem;

@interface VideoThumbnailCell : PhotoAlbumCoverView

+ (NSString *) cellReuseIdentifier;

- (void) setCellData : (MWFeedItem *) itemData;

@end
