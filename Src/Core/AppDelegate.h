#import <CoreData/CoreData.h>
#import <UIKit/UIKit.h>

namespace CernAPP {

enum class TwitterFeedShowOption : char {
   notSet,
   externalView,
   builtinView
};

}

@interface AppDelegate : UIResponder <UIApplicationDelegate, NSURLConnectionDelegate, NSURLConnectionDataDelegate>

- (void) cacheData : (NSObject *) data withKey : (NSObject<NSCopying> *) key;
- (NSObject *) cacheForKey : (NSObject<NSCopying> *) key;
- (void) clearFeedCache;

- (void) setGTMForKey : (NSObject<NSCopying> *) key;
- (NSDate *) GMTForKey : (NSObject<NSCopying> *) key;

@property (strong, nonatomic) UIWindow *window;

//How to show tweets?
@property (nonatomic) CernAPP::TwitterFeedShowOption tweetOption;

//OAuth data for Readability.
@property (nonatomic, copy) NSString *OAuthToken;
@property (nonatomic, copy) NSString *OAuthTokenSecret;

@property (nonatomic, strong) NSDictionary *APNdictionary;

//CoreData to save/restore feeds.
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@end
