#import <UIKit/UIKit.h>

#import "ConnectionController.h"
#import "MARCParserOperation.h"
#import "HUDRefreshProtocol.h"
#import "ImageDownloader.h"
#import "MWPhotoBrowser.h"

//PhotosCollectionViewController shows images grouped into albums or "stacks".

@class MBProgressHUD;

@interface PhotoCollectionsViewController : UICollectionViewController<UICollectionViewDataSource, UICollectionViewDelegate,
                                                                      ImageDownloaderDelegate, HUDRefreshProtocol,
                                                                      MARCParserOperationDelegate, ConnectionController,
                                                                      MWPhotoBrowserDelegate>


- (void) setURLString : (NSString *) urlString;

//HUD/UI
@property (nonatomic, strong) MBProgressHUD *noConnectionHUD;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;

@end