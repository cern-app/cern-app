#import <Foundation/Foundation.h>

namespace CernAPP {

NSArray *ReadFeedCache(NSString *feedStoreID);
//Converts an array of NSManagedObject into an array of MWFeedItems (and sorts them using
//the date).
NSMutableArray *ConvertFeedCache(NSArray *feedCache);
void WriteFeedCache(NSString *feedStoreID, NSArray *feedCache, NSArray *allArticles);

}