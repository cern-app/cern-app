#import "AppDelegate.h"

@implementation AppDelegate

@synthesize window = _window;
@synthesize tweetOption;
@synthesize OAuthToken, OAuthTokenSecret, managedObjectContext, managedObjectModel, persistentStoreCoordinator;

//________________________________________________________________________________________
- (BOOL) application : (UIApplication *) application didFinishLaunchingWithOptions : (NSDictionary *) launchOptions
{
   [[UIBarButtonItem appearance] setTintColor : [UIColor colorWithRed : 0.f green : 83.f / 255.f blue : 161.f / 255.f alpha : 1.f]];
   //
   NSUserDefaults * const defaults = [NSUserDefaults standardUserDefaults];
   NSDictionary * const appDefaults = [NSDictionary dictionaryWithObjectsAndKeys:@13, @"GUIFontSize", @0, @"HTMLBodyFontSize", nil];
   [defaults registerDefaults : appDefaults];
   [defaults synchronize];
   
   tweetOption = CernAPP::TwitterFeedShowOption::notSet;
   //
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

@end
