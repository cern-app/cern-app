#import <UIKit/UIKit.h>

#import "ConnectionController.h"
#import "APNEnabledController.h"
#import "ImageDownloader.h"
#import "MWFeedParser.h"

@interface WebcastsCollectionViewController : UICollectionViewController<MWFeedParserDelegate, ConnectionController,
                                                                         ImageDownloaderDelegate, APNEnabledController>

- (void) setControllerData : (NSArray *) dataItems;

@property (nonatomic) NSUInteger apnID;
@property (nonatomic) NSUInteger apnItems;

@end
