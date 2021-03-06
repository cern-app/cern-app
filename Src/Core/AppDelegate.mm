#import <UserNotifications/UserNotifications.h>

#import "InitialSlidingViewController.h"
#import "MenuViewController.h"
#import "DeviceCheck.h"
#import "AppDelegate.h"

//TODO: this should become 'Details.h' or something like this.
#import "TwitterAPI.h"

namespace CernAPP {

NSString * const guiFontSizeKey      = @"GUIFontSize";
NSString * const htmlBodyFontSizeKey = @"HTMLBodyFontSize";
NSString * const tweetViewKey        = @"ShowTwitterFeedIn";

//________________________________________________________________________________________
NSDate *GetCurrentGMT()
{
   NSDate * const localDate = [NSDate date];
   NSTimeZone * const currentTimeZone = [NSTimeZone localTimeZone];
   const NSInteger currentGMTOffset = [currentTimeZone secondsFromGMT];
   return [localDate dateByAddingTimeInterval : -currentGMTOffset];
}

}

namespace {

enum class RequestType : unsigned char {
    none,
    tokenRegistration,
    notificationRequest
};

NSString * const deviceTokenKey = @"DeviceToken";
NSString * const apnKeyFormat = @"apn%lu";

}

@implementation AppDelegate {
   NSURLConnection *connection;
   NSMutableDictionary *appCache;
   
   RequestType mode;
   NSMutableData *connectionData;
   NSString *newAPNToken;
   NSMutableDictionary *apnCache;
}

@synthesize window = _window;
@synthesize tweetOption;
@synthesize OAuthToken, OAuthTokenSecret, APNdictionary, managedObjectContext, managedObjectModel, persistentStoreCoordinator;

//________________________________________________________________________________________
- (void) dealloc
{
   //It's possible, that we still have an active NSURLConnection, sending
   //our device's token for a registration. Cancell the connection.

   if (connection)
      [connection cancel];

   connection = nil;
}

//________________________________________________________________________________________
- (BOOL) application : (UIApplication *) application didFinishLaunchingWithOptions : (NSDictionary *) launchOptions
{
   //1. Set a tint color for a navigation bar's button.
   //2. Read app's defaults: font sizes for GUI elements (a menu) and
   //   for the "Readability" view.
   //3. Register our device for APN.

   if (CernAPP::SystemVersionLessThan(@"7.0"))
      [[UIBarButtonItem appearance] setTintColor : [UIColor colorWithRed : 0.f green : 83.f / 255.f blue : 161.f / 255.f alpha : 1.f]];

   // Set fallback user defaults
   NSUserDefaults * const defaults = [NSUserDefaults standardUserDefaults];
   NSDictionary * const appDefaults = [NSDictionary dictionaryWithObjectsAndKeys :
                                       @13,  CernAPP::guiFontSizeKey,
                                       @0,   CernAPP::htmlBodyFontSizeKey,
                                       @YES, CernAPP::tweetViewKey, nil];
   [defaults registerDefaults : appDefaults];
   [defaults synchronize];

   BOOL opt = [defaults boolForKey : CernAPP::tweetViewKey];
   tweetOption = CernAPP::TwitterFeedShowOption(opt);
   
   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
   /*   const unsigned cacheSizeMemory = 4 * 1024 * 1024; // 4MB
      const unsigned  cacheSizeDisk = 32 * 1024 * 1024; // 32MB
      NSURLCache * const sharedCache = [[NSURLCache alloc] initWithMemoryCapacity : cacheSizeMemory diskCapacity : cacheSizeDisk diskPath : @"nsurlcache"];
      [NSURLCache setSharedURLCache : sharedCache];*/
   }
   
   //APN.
   mode = RequestType::none;
#ifndef TARGET_IPHONE_SIMULATOR
   UNUserNotificationCenter *unCenter = [UNUserNotificationCenter currentNotificationCenter];
   [unCenter requestAuthorizationWithOptions : UNAuthorizationOptionAlert | UNAuthorizationOptionBadge | UNAuthorizationOptionSound
    completionHandler : ^(BOOL granted, NSError * _Nullable error) {
        if (granted)
            [[UIApplication sharedApplication] registerForRemoteNotifications];
    }];
#endif

   // TODO: I do not remember why I have this if statement (should it be unconditional?)
   if (!APNdictionary)
      APNdictionary = (NSDictionary *)[launchOptions objectForKey : UIApplicationLaunchOptionsRemoteNotificationKey];

   // Clear a badge + remove notifications from the notification center.
   [UIApplication sharedApplication].applicationIconBadgeNumber = 0;

   return YES;
}

//________________________________________________________________________________________
- (void) applicationWillResignActive : (UIApplication *) application
{
  /*
   Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
   Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
   */
}

//________________________________________________________________________________________
- (void) applicationDidEnterBackground : (UIApplication *) application
{
  /*
   Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
   If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
   */
}

//________________________________________________________________________________________
- (void) applicationWillEnterForeground : (UIApplication *) application
{
  /*
   Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
   */
}

//________________________________________________________________________________________
- (void) applicationDidBecomeActive : (UIApplication *) application
{
  /*
   Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
   */
}

//________________________________________________________________________________________
- (void) applicationWillTerminate : (UIApplication *) application
{
  /*
   Called when the application is about to terminate.
   Save data if appropriate.
   See also applicationDidEnterBackground:.
   */
}

#pragma mark - Cache management (and more general - update timestamps etc.).

//________________________________________________________________________________________
- (void) cacheData : (NSObject *) data withKey : (NSObject<NSCopying> *) key
{
   //Cache arbitrary data in the app delegate.
   assert(data != nil && "cacheData:withKey:, parameter 'data' is nil");
   assert(key != nil && "cacheData:withKey:, parameter 'key' is nil");

   if (!appCache)
      appCache = [[NSMutableDictionary alloc] init];

   [appCache setObject : data forKey : key];
}

//________________________________________________________________________________________
- (NSObject *) cacheForKey : (NSObject<NSCopying> *) key
{
   assert(key != nil && "cacheForKey:, parameter 'key' is nil");
   
   if (!appCache)
      return nil;

   return appCache[key];
}

//________________________________________________________________________________________
- (void) clearFeedCache
{
   [appCache removeAllObjects];
   appCache = nil;
}

//________________________________________________________________________________________
- (void) setGMTForKey : (NSString *) key
{
   assert(key != nil && key.length > 0 && "setGMTForKey:, parameter 'key' is invalid");
   
   [[NSUserDefaults standardUserDefaults] setObject : CernAPP::GetCurrentGMT()
                                          forKey : [@"timestamp_" stringByAppendingString : key]];
   [[NSUserDefaults standardUserDefaults] synchronize];
}

//________________________________________________________________________________________
- (NSDate *) GMTForKey : (NSString *) key
{
   assert(key != nil && "GMTForKey:, parameter 'key' is nil");
   
   return (NSDate *)[[NSUserDefaults standardUserDefaults] objectForKey : [@"timestamp_" stringByAppendingString : key]];
}

#pragma mark - Core data management.

//________________________________________________________________________________________
- (NSManagedObjectContext *) managedObjectContext
{
   //Returns the managed object context for the application.
   //If the context doesn't already exist, it is created and bound
   //to the persistent store coordinator for the application.

   if (managedObjectContext)
      return managedObjectContext;

   if (NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator]) {
      managedObjectContext = [[NSManagedObjectContext alloc] init];
      [managedObjectContext setPersistentStoreCoordinator : coordinator];
   }
   
   return managedObjectContext;
}

//________________________________________________________________________________________
- (NSManagedObjectModel *) managedObjectModel
{
   //Returns the managed object model for the application.
   //If the model doesn't already exist, it is created
   //from the application's model.

   if (managedObjectModel)
      return managedObjectModel;

   NSURL * const modelURL = [[NSBundle mainBundle] URLForResource : @"Model" withExtension : @"momd"];
   managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL : modelURL];

   return managedObjectModel;
}

//________________________________________________________________________________________
- (NSPersistentStoreCoordinator *) persistentStoreCoordinator
{
   //Returns the persistent store coordinator for the application.
   //If the coordinator doesn't already exist, it is created
   //and the application's store added to it.

   if (persistentStoreCoordinator)
      return persistentStoreCoordinator;

   //TODO: add error handling!

   NSString * const directory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
   NSURL * const storeURL = [[NSURL fileURLWithPath : directory] URLByAppendingPathComponent : @"CERN.sqlite"];

   NSError *error = nil;
   persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel : [self managedObjectModel]];
   if (![persistentStoreCoordinator addPersistentStoreWithType : NSSQLiteStoreType configuration : nil URL : storeURL options : nil error : &error]) {
      //Handle error
      NSLog(@"persistentStoreCoordinator, %@", error);
   }

   return persistentStoreCoordinator;
}

#pragma mark - Application's Documents directory

//________________________________________________________________________________________
- (NSURL *) applicationDocumentsDirectory
{
   // Returns the URL to the application's Documents directory.
   return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

#pragma mark - APN.

//________________________________________________________________________________________
- (void) checkForAPNUpdates
{
   assert(connection == nil && "checkForAPNUpdates, has active connection");
   
   if (NSString * const deviceToken = [[NSUserDefaults standardUserDefaults] stringForKey : deviceTokenKey]) {
      if (NSString * const request = CernAPP::Details::GetAPNNotificationsRequest(deviceToken)) {
         connectionData = [[NSMutableData alloc] init];
         mode = RequestType::notificationRequest;
         connection = [[NSURLConnection alloc] initWithRequest : [NSURLRequest requestWithURL : [NSURL URLWithString : request]] delegate : self];         
      }
   }
}

//________________________________________________________________________________________
- (void) application : (UIApplication*) application didRegisterForRemoteNotificationsWithDeviceToken : (NSData*) deviceToken
{
#pragma unused(application)

   using namespace CernAPP::Details;

   if (!deviceToken) {
      NSLog(@"error: application:didRegisterForRemoveNotificationsWithDeviceToken:, parameter 'deviceToken' is nil");
      return;
   }

   NSString * const oldToken = [[NSUserDefaults standardUserDefaults] stringForKey : deviceTokenKey];

   newAPNToken = [deviceToken description];
   newAPNToken  = [newAPNToken  stringByTrimmingCharactersInSet : [NSCharacterSet characterSetWithCharactersInString : @"<>"]];
   newAPNToken  = [newAPNToken  stringByReplacingOccurrencesOfString : @" " withString : @""];

   if (oldToken && [oldToken isEqualToString : newAPNToken]) {
      newAPNToken = nil;
      return;
   }

   NSString * const request = !oldToken ? GetAPNRegisterDeviceTokenRequest(newAPNToken) :
                                          GetAPNUpdateDeviceTokenRequest(oldToken, newAPNToken);
   if (request) {
      mode = RequestType::tokenRegistration;
      connection = [[NSURLConnection alloc] initWithRequest : [NSURLRequest requestWithURL : [NSURL URLWithString : request]] delegate : self];
   } else
      NSLog(@"error: invalid token registration request for device token %@", deviceToken);
}

//________________________________________________________________________________________
- (void) application : (UIApplication*) application didFailToRegisterForRemoteNotificationsWithError : (NSError*) error
{
#pragma unused(application)

   NSLog(@"error: failed to register for APN - %@", error);
}

//________________________________________________________________________________________
- (void) application : (UIApplication *) application didReceiveRemoteNotification : (NSDictionary *) userInfo
{
#pragma unused(application)

   if (userInfo && !APNdictionary) {//We still have an active APN, forget about this new one.
      APNdictionary = userInfo;
      InitialSlidingViewController * controller = (InitialSlidingViewController *)_window.rootViewController;
      if ([controller.underLeftViewController isKindOfClass : [MenuViewController class]]) {
         MenuViewController * const mvc = (MenuViewController *)controller.underLeftViewController;
         [mvc checkPushNotifications];
      }
   }
}

//________________________________________________________________________________________
- (NSString *) apnKey : (NSUInteger) apnID
{
   assert(apnID != 0 && "apnKey:, parameter 'apnID' is not a valid id");
   return [NSString stringWithFormat : @"apn%lu", (unsigned long)apnID];
}

//________________________________________________________________________________________
- (void) cacheAPNHash : (NSString *) hash forFeed : (NSUInteger) apnID
{
   assert(apnID != 0 && "cacheAPNHash:forFeed:, parameter 'apnID' is invalid");

   if (!apnCache)
      apnCache = [[NSMutableDictionary alloc] init];
   
   [apnCache setObject : hash forKey : [self apnKey : apnID]];
}

//________________________________________________________________________________________
- (NSString *) APNHashForFeed : (NSUInteger) apnID
{
   assert(apnID != 0 && "APNHashForFeed:, parameter 'apnID' is invalid");
   
   if (!apnCache)//Should be assert actually.
      return nil;
   
   return (NSString *)apnCache[[self apnKey : apnID]];
}

//________________________________________________________________________________________
- (void) removeAPNHashForFeed : (NSUInteger) apnID
{
   assert(apnID != 0 && "removeAPNHashForFeed:, parameter 'apnID' is invalid");
   
   if (!apnCache)
      return;
   
   NSString * const key = [self apnKey : apnID];
   if (apnCache[key])
      [apnCache removeObjectForKey : key];
}

#pragma mark - NSURLConnectionDataDelegate.

//________________________________________________________________________________________
- (void) connection : (NSURLConnection *) aConnection didReceiveData : (NSData *) data
{
#pragma unused(aConnection)

   if (mode == RequestType::notificationRequest) {
      assert(data != nil && "connection:didReceiveData:, parameter 'data' is nil");
      [connectionData appendData : data];
   }
}

#pragma mark - NSURLConnectionDelegate.

//________________________________________________________________________________________
- (void) connectionDidFinishLoading : (NSURLConnection *) aConnection
{
#pragma unused(aConnection)
   connection = nil;
   if (mode == RequestType::notificationRequest) {
      NSError *err = nil;
      NSDictionary * const json = [NSJSONSerialization JSONObjectWithData : connectionData options : NSJSONReadingAllowFragments error : &err];
      if (json)
         NSLog(@"got notifications: %@", json);
   } else if (mode == RequestType::tokenRegistration) {
      if (newAPNToken) {//Should be assert actually.
         [[NSUserDefaults standardUserDefaults] setObject : newAPNToken forKey : deviceTokenKey];
         [[NSUserDefaults standardUserDefaults] synchronize];
         newAPNToken = nil;
      }
   }
}

//________________________________________________________________________________________
- (void) connection : (NSURLConnection *) aConnection didFailWithError : (NSError *) error
{
#pragma unused(aConnection)

   connection = nil;
   if (mode == RequestType::tokenRegistration)
      NSLog(@"failed to register device's token: %@", error);
   else
      NSLog(@"failed to fetch notifications");
}

@end
