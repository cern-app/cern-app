#import <UIKit/UIKit.h>

#import "TiledPage.h"

@interface FeedPageView : UIView<TiledPage>


//TiledPage protocol:
@property (nonatomic) NSUInteger pageNumber;

+ (NSRange) suggestRangeForward : (NSArray *) items startingFrom : (NSUInteger) index;
+ (NSRange) suggestRangeBackward : (NSArray *) items endingWith : (NSUInteger) index;

- (NSUInteger) setPageItems : (NSArray *) feedItems startingFrom : (NSUInteger) index;

@property (nonatomic, readonly) NSRange pageRange;

- (void) setThumbnail : (UIImage *) thumbnailImage forTile : (NSUInteger) tileIndex doLayout : (BOOL) layout;
- (BOOL) tileHasThumbnail : (NSUInteger) tileIndex;

- (void) layoutTiles;

//Animations:
- (void) explodeTiles : (UIInterfaceOrientation) orientation;
//Actually, both CFTimeInterval and NSTimeInterval are typedefs for double.
- (void) unzoomAnimatedWithZoom : (CGFloat) zoom from : (CFTimeInterval) start withDuration : (CFTimeInterval) duration;
- (void) collectTilesAnimatedForOrientation : (UIInterfaceOrientation) orientation from : (CFTimeInterval) start withDuration : (CFTimeInterval) duration;
//
- (void) setScaleFactor : (CGFloat) factor;
- (void) unscale;
//


@end
