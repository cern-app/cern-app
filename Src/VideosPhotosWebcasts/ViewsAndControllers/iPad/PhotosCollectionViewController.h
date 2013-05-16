#import <UIKit/UIKit.h>


#import "ConnectionController.h"
#import "HUDRefreshProtocol.h"
#import "PhotoDownloader.h"
#import "MWPhotoBrowser.h"

@class MBProgressHUD;

@interface PhotosCollectionViewController : UICollectionViewController<UICollectionViewDataSource, UICollectionViewDelegate,
                                                                       PhotoDownloaderDelegate, HUDRefreshProtocol>
//                                                                       MWPhotoBrowserDelegate>

@property (nonatomic, strong) PhotoDownloader *photoDownloader;

- (IBAction) reloadImages : (id) sender;
- (IBAction) revealMenu : (id) sender;


//HUD/GUI
@property (nonatomic, strong) MBProgressHUD *noConnectionHUD;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;

@end