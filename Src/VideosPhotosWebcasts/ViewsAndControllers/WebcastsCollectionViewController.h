#import <UIKit/UIKit.h>

#import "ConnectionController.h"
#import "ImageDownloader.h"
#import "MWFeedParser.h"

@interface WebcastsCollectionViewController : UICollectionViewController<MWFeedParserDelegate, ConnectionController,
                                                                         ImageDownloaderDelegate>

- (void) setControllerData : (NSArray *) dataItems;

- (void) setApnID : (NSNumber *) apnID;//NSNumber, method is called by performSelector:withObject:.


@end
