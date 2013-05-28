#import <UIKit/UIKit.h>

#import "ConnectionController.h"
#import "ImageDownloader.h"
#import "MWFeedParser.h"

@interface WebcastsCollectionViewController : UICollectionViewController<MWFeedParserDelegate, ConnectionController,
                                                                         ImageDownloaderDelegate>

- (void) setControllerData : (NSArray *) dataItems;

@end
