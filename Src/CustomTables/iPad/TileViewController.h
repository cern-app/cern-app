#import <UIKit/UIKit.h>

#import "SlideScrollView.h"
#import "TiledPage.h"

//Base class for "tiled views" controllers:
//on iPad we organize different feed views
//in a 'newspaper-like' way. Individual
//feed items are placed like tiles on a page,
//and we can have many pages in a scrollview.
//TileViewController is responsible for geometry,
//rotation animations, and "infinite scroll view" trick.

@interface TileViewController : UIViewController {  
@protected
   IBOutlet SlideScrollView *scrollView;
   NSMutableArray *dataItems;
   NSUInteger nPages;
   UIView<TiledPage> *leftPage;
   UIView<TiledPage> *currPage;
   UIView<TiledPage> *rightPage;
}

- (void) setPagesData;//To be overriden.
- (void) loadVisiblePageData;//To be overriden.
- (void) layoutPages : (BOOL) layoutTiles;
- (void) adjustPages;
- (NSRange) findItemRangeForPage : (NSUInteger) page;

//ECSlidingViewController:
- (IBAction) revealMenu : (id) sender;

@end
