#import <UIKit/UIKit.h>

#import "ConnectionController.h"
#import "CernMediaMARCParser.h"
#import "HUDRefreshProtocol.h"
#import "ImageDownloader.h"
#import "MWPhotoBrowser.h"

@class MBProgressHUD;

@interface PhotosCollectionViewController : UICollectionViewController<UICollectionViewDataSource, UICollectionViewDelegate,
                                                                       ImageDownloaderDelegate, HUDRefreshProtocol,
                                                                       CernMediaMarcParserDelegate, ConnectionController>

- (void) setURL : (NSURL *) url;
@property (nonatomic) BOOL stackedMode;

//UI actions (buttons on the navigation bar).
- (IBAction) reloadImages : (id) sender;
- (IBAction) revealMenu : (id) sender;

//HUD/UI
@property (nonatomic, strong) MBProgressHUD *noConnectionHUD;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;

@end