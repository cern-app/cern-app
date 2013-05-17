#import <UIKit/UIKit.h>


#import "ConnectionController.h"
#import "HUDRefreshProtocol.h"
#import "ImageDownloader.h"
//#import "PhotoDownloader.h"
#import "MWPhotoBrowser.h"

@class MBProgressHUD;

@interface PhotosCollectionViewController : UICollectionViewController<UICollectionViewDataSource, UICollectionViewDelegate,
                                                                       ImageDownloaderDelegate, HUDRefreshProtocol>
//                                                                       MWPhotoBrowserDelegate>

- (IBAction) reloadImages : (id) sender;
- (IBAction) revealMenu : (id) sender;


@property (nonatomic) BOOL stackedMode;

//HUD/GUI
@property (nonatomic, strong) MBProgressHUD *noConnectionHUD;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;

@end