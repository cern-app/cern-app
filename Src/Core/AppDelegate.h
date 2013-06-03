#import <CoreData/CoreData.h>
#import <UIKit/UIKit.h>

namespace CernAPP {

enum class TwitterFeedShowOption : char {
   notSet,
   externalView,
   builtinView
};

}

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

//How to show tweets?
@property (nonatomic) CernAPP::TwitterFeedShowOption tweetOption;

//OAuth data for Readability.
@property (nonatomic, copy) NSString *OAuthToken;
@property (nonatomic, copy) NSString *OAuthTokenSecret;

//CoreData to save/restore feeds.
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@end
