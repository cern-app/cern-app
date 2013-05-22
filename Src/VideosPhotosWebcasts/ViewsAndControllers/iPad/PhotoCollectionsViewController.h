#import <UIKit/UIKit.h>

#import "ConnectionController.h"
#import "CernMediaMARCParser.h"
#import "HUDRefreshProtocol.h"
#import "ImageDownloader.h"
#import "MWPhotoBrowser.h"

//TODO: This class (non-stacked mode) should also replace a PhotoGridViewController (iPhone version).


//PhotosCollectionViewController shows images grouped into albums or "stacks".

@class MBProgressHUD;

@interface PhotoCollectionsViewController : UICollectionViewController<UICollectionViewDataSource, UICollectionViewDelegate,
                                                                      ImageDownloaderDelegate, HUDRefreshProtocol,
                                                                      CernMediaMarcParserDelegate, ConnectionController>


- (void) setURL : (NSURL *) url;

//UI actions (buttons on the navigation bar).
- (IBAction) reloadImages : (id) sender;
- (IBAction) revealMenu : (id) sender;

//HUD/UI
@property (nonatomic, strong) MBProgressHUD *noConnectionHUD;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;

@end