#import <UIKit/UIKit.h>

#import "ConnectionController.h"
#import "APNEnabledController.h"
#import "ImageDownloader.h"
#import "MWFeedParser.h"

@interface WebcastsCollectionViewController : UICollectionViewController<MWFeedParserDelegate, ConnectionController,
                                                                         ImageDownloaderDelegate>

- (void) setControllerData : (NSArray *) dataItems;

@property (nonatomic) NSUInteger apnID;
//- (void) addAPNItems : (NSUInteger) newItems;

@end
