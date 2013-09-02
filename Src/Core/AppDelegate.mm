#import "InitialSlidingViewController.h"
#import "MenuViewController.h"
#import "AppDelegate.h"

//TODO: this should become 'Details.h' or something like this.
#import "TwitterAPI.h"

@implementation AppDelegate {
   NSURLConnection *tokenServerConnection;
   NSMutableDictionary *cachedFeeds;
}

@synthesize window = _window;
@synthesize tweetOption;
@synthesize OAuthToken, OAuthTokenSecret, APNdictionary, managedObjectContext, managedObjectModel, persistentStoreCoordinator;

//________________________________________________________________________________________
- (void) dealloc
{
   //It's possible, that we still have an active NSURLConnection, sending
   //our device's token for a registration. Cancell the connection.

   if (tokenServerConnection)
      [tokenServerConnection cancel];

   tokenServerConnection = nil;
}

//________________________________________________________________________________________
- (BOOL) application : (UIApplication *) application didFinishLaunchingWithOptions : (NSDictionary *) launchOptions
{
   //1. Set a tint color for a navigation bar's button.
   //2. Read app's defaults: font sizes for GUI elements (a menu) and
   //   for the "Readability" view.
   //3. Register our device for APN.

   [[UIBarButtonItem appearance] setTintColor : [UIColor colorWithRed : 0.f green : 83.f / 255.f blue : 161.f / 255.f alpha : 1.f]];

   NSUserDefaults * const defaults = [NSUserDefaults standardUserDefaults];
   NSDictionary * const appDefaults = [NSDictionary dictionaryWithObjectsAndKeys : @13, @"GUIFontSize", @0, @"HTMLBodyFontSize", nil];
   [defaults registerDefaults : appDefaults];
   [defaults synchronize];
   
   tweetOption = CernAPP::TwitterFeedShowOption::notSet;
   
   
   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
   /*   const unsigned cacheSizeMemory = 4 * 1024 * 1024; // 4MB
      const unsigned  cacheSizeDisk = 32 * 1024 * 1024; // 32MB
      NSURLCache * const sharedCache = [[NSURLCache alloc] initWithMemoryCapacity : cacheSizeMemory diskCapacity : cacheSizeDisk diskPath : @"nsurlcache"];
      [NSURLCache setSharedURLCache : sharedCache];*/
   }
   
   //APN.
   [[UIApplication sharedApplication] registerForRemoteNotificationTypes : UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert];
   //TODO: this should go away - in the nearest future all the data will be removed from the payload.
   APNdictionary = (NSDictionary *)[launchOptions objectForKey : UIApplicationLaunchOptionsRemoteNotificationKey];

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

#pragma mark - Feed cache management.

//________________________________________________________________________________________
- (void) cacheData : (NSMutableArray *) dataItems forFeed : (NSString *) feedID
{
   //In order to save traffic/time, we're going to cache a result of successfull feed parse operation
   //for future use (if a user again selects the same feed after some other items in a menu).

   assert(dataItems != nil && "cacheData:forFeed:, parameter 'dataItems' is nil");
   assert(feedID != nil && "cacheData:forFeed:, parameter 'feedID' is nil");

   if (!cachedFeeds)
      cachedFeeds = [[NSMutableDictionary alloc] init];

   [cachedFeeds setObject : dataItems forKey : feedID];
}

//________________________________________________________________________________________
- (NSMutableArray *) cacheForFeed : (NSString *) feedID
{
   //When feed view controller is loaded, reuse previous parsed items (if any).
   
   assert(feedID != nil && "cacheForFeed:, parameter 'feedID' is nil");
   
   if (!cachedFeeds)
      return nil;

   return (NSMutableArray *)cachedFeeds[feedID];
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
- (void) application : (UIApplication*) application didRegisterForRemoteNotificationsWithDeviceToken : (NSData*) deviceToken
{
#pragma unused(application)

   assert(deviceToken != nil && "application:didRegisterForRemoteNotificationsWithDeviceToken:, parameter 'deviceToken' is nil");
   
   NSString *tokenString = [deviceToken description];
   tokenString = [tokenString stringByTrimmingCharactersInSet : [NSCharacterSet characterSetWithCharactersInString : @"<>"]];
   tokenString = [tokenString stringByReplacingOccurrencesOfString : @" " withString : @""];
   
   if (NSString * const request = CernAPP::Details::GetAPNRegisterDeviceTokenRequest(tokenString))
      tokenServerConnection = [[NSURLConnection alloc] initWithRequest : [NSURLRequest requestWithURL : [NSURL URLWithString : request]] delegate : self];
   else
      NSLog(@"invalid token registration request for device token %@", deviceToken);
}

//________________________________________________________________________________________
- (void) application : (UIApplication*) application didFailToRegisterForRemoteNotificationsWithError : (NSError*) error
{
#pragma unused(application)

   NSLog(@"failed to register for APN: %@", error);
}

//________________________________________________________________________________________
- (void) application : (UIApplication *) application didReceiveRemoteNotification : (NSDictionary *) userInfo
{
#pragma unused(application)
   if (userInfo) {
      APNdictionary = userInfo;
      InitialSlidingViewController * controller = (InitialSlidingViewController *)_window.rootViewController;
      if ([controller.underLeftViewController isKindOfClass : [MenuViewController class]]) {
         MenuViewController * const mvc = (MenuViewController *)controller.underLeftViewController;
         [mvc checkPushNotifications];
      }
   }
}

#pragma mark - NSURLConnectionDelegate.

//________________________________________________________________________________________
- (void) connectionDidFinishLoading : (NSURLConnection *) connection
{
   tokenServerConnection = nil;
   //Registered now (?)
}

//________________________________________________________________________________________
- (void) connection : (NSURLConnection *) connection didFailWithError : (NSError *) error
{
#pragma unused(connection)

   tokenServerConnection = nil;
   NSLog(@"failed to register device's token: %@", error);
}

@end
