#import <UIKit/UIKit.h>

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

@interface TileViewController : UIViewController<FlipAnimatedViewController> {
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
   UIView *panRegion;   
}

- (void) setPagesData;//To be overriden.
- (void) loadVisiblePageData;//To be overriden.
- (void) layoutPages : (BOOL) layoutTiles;
- (void) layoutFlipView;

- (NSRange) findItemRangeForPage : (NSUInteger) page;

//ECSlidingViewController:
- (IBAction) revealMenu : (id) sender;

@end
