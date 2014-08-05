#import <Foundation/Foundation.h>

@class MWFeedItem;

namespace CernAPP {

//Aux. functions to extract URLs or URLs as strings from different sources.
NSString *FindUnescapedImageURLStringInHTMLString(NSString *htmlString);
NSString *FindImageURLStringInHTMLString(NSString *htmlString);
NSURL *FindImageURLInHTMLString(NSString *htmlString);

NSString *FindUnescapedImageURLStringInEnclosures(MWFeedItem *article);
NSString *FindImageURLStringInEnclosures(MWFeedItem *article);
NSURL *FindImageURLInEnclosures(MWFeedItem *article);

}
