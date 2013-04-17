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
@private
   IBOutlet SlideScrollView *scrollView;
@protected
   NSMutableArray *dataItems;
   UIView<TiledPage> *leftPage;
   UIView<TiledPage> *currPage;
   UIView<TiledPage> *rightPage;
}

//To be overriden: the page became
//visible, do any 'lazy' load here.
- (void) loadVisiblePageData;

//ECSlidingViewController:
- (IBAction) revealMenu : (id) sender;

@end
