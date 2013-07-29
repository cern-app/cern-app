#import <UIKit/UIKit.h>

#import "HUDRefreshProtocol.h"
#import "AnimationDelegate.h"
#import "SlideScrollView.h"
#import "TiledPage.h"

//Base class for "tiled views" controllers:
//on iPad we organize different feed views
//in a 'newspaper-like' way. Individual
//feed items are placed like tiles on a page,
//and we can have many pages in a scrollview.
//TileViewController is responsible for geometry,
//rotation animations, and "infinite scroll view" trick.

@class AnimationDelegate;
@class FlipView;

@interface TileViewController : UIViewController<FlipAnimatedViewController, HUDRefreshProtocol> {
@protected
   NSMutableArray *dataItems;
   NSUInteger nPages;
   
   //'Previous', 'next' have the same
   //meaning as in FlipView (if
   //flip the page back, you go to the 'next' page).
   UIView<TiledPage> *prevPage;
   UIView<TiledPage> *currPage;
   UIView<TiledPage> *nextPage;
   
   AnimationDelegate *flipAnimator;
   FlipView *flipView;

   UIPanGestureRecognizer *panGesture;   
   UIView *panRegion;
   
   BOOL delayedFlipRefresh;
}

- (id) initWithCoder : (NSCoder *) aDecoder;

//Create additional views: flipView, panRegion,
//create and setup a flipAnimator.
- (void) viewDidLoad;

//This is a trick: check number of pages loaded and
//check the geometry, if it has to be reset:
//sometimes, after controller is presented on the top
//of a tile view, interface orientation change is not processed
//correctly. In such a case this method resets flipView, panRegion,
//pages.
- (void) viewWillAppear : (BOOL) animated;


//After dataItems were loaded (either the first time
//or after refreshing, this function (re)sets pages.
- (void) setPagesData;//To be overriden.
//Lazy download - we load (for example images)
//only for a visible page.
- (void) loadVisiblePageData;//To be overriden.

//Set the page's geometry and (probably) tiles' geometry also.
- (void) layoutPages : (BOOL) layoutTiles;
//Set the flip view's geometry and flip anilmation frames.
- (void) layoutFlipView;
//Set pan view's geometry.
- (void) layoutPanRegion;

//"UI".
- (void) showRightFlipHint;
- (void) showLeftFlipHint;
- (void) hideFlipHint;

//Using dataItems and page layout identify, how many items
//fit the page.
- (NSRange) findItemRangeForPage : (NSUInteger) pageIndex;

//ECSlidingViewController:
- (IBAction) revealMenu : (id) sender;

//HUDRefreshProtocol.
@property (nonatomic, strong) MBProgressHUD *noConnectionHUD;//Error messages.
@property (nonatomic, strong) UIActivityIndicatorView *spinner;

//To be overriden:
- (void) refreshAfterFlip;


@end
