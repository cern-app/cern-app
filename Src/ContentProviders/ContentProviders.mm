#import <cassert>

#import "PhotoCollectionsViewController.h"
#import "StaticInfoScrollViewController.h"
#import "VideosCollectionViewController.h"
#import "StaticInfoTileViewController.h"
#import "BulletinTableViewController.h"
#import "BulletinFeedViewController.h"
#import "EventDisplayViewController.h"
#import "VideosGridViewController.h"
#import "MenuNavigationController.h"
#import "PhotosGridViewController.h"
#import "LiveEventTableController.h"
#import "NewsTableViewController.h"
#import "ECSlidingViewController.h"
#import "NewsFeedViewController.h"
#import "StoryboardIdentifiers.h"
#import "ConnectionController.h"
#import "ApplicationErrors.h"//TODO: remove when all controllers are activated.
#import "ContentProviders.h"
#import "KeyVal.h"

namespace {

//________________________________________________________________________________________
void CancelConnections(UIViewController *controller)
{
   assert(controller != nil && "CancelConnections, parameter 'controller' is nil");

   if ([controller respondsToSelector : @selector(cancelAnyConnections)])
      [controller performSelector : @selector(cancelAnyConnections)];
}

}

@implementation FeedProvider {
   NSString *feedName;
   NSString *feed;
   UIImage *feedImage;
   BOOL isTwitterFeed;
}

//________________________________________________________________________________________
- (id) initWith : (NSDictionary *) feedInfo
{
   assert(feedInfo != nil && "initWith:, feedInfo parameter is nil");

   if (self = [super init]) {
      id base = [feedInfo objectForKey : @"Name"];
      assert(base != nil && [base isKindOfClass : [NSString class]] && "initWith:, object for 'Name' was not found or is not of string type");
      
      feedName = (NSString *)base;

      base = [feedInfo objectForKey : @"Url"];
      assert(base != nil && [base isKindOfClass : [NSString class]] && "initWith:, object for 'Url' was not found or is not of string type");
      
      feed = (NSString *)base;
      
      if ([feedInfo[@"Image"] isKindOfClass : [NSString class]])
         feedImage = [UIImage imageNamed:(NSString *)feedInfo[@"Image"]];
      
      if (feedInfo[@"Category name"]) {
         assert([feedInfo[@"Category name"] isKindOfClass : [NSString class]] &&
                "initWith:, 'Category name' has a wrong type");
         
         if ([(NSString *)feedInfo[@"Category name"] isEqualToString : @"Tweet"])
            isTwitterFeed = YES;
         else
            isTwitterFeed = NO;
      }
   }
   
   return self;
}

//________________________________________________________________________________________
- (NSString *) categoryName
{
   return feedName;
}

//________________________________________________________________________________________
- (void) setCategoryName : (NSString *) name
{
   feedName = name;
}

//________________________________________________________________________________________
- (UIImage *) categoryImage
{
   return feedImage;
}

//________________________________________________________________________________________
- (void) loadControllerTo : (UIViewController *) controller
{
   using namespace CernAPP;

   assert(controller != nil && "loadControllerTo:, parameter controller is nil");

   MenuNavigationController *navController = nil;
 
   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
      navController = (MenuNavigationController *)[controller.storyboard instantiateViewControllerWithIdentifier :
                                                                         TableNavigationControllerNewsID];
      assert([navController.topViewController isKindOfClass : [NewsTableViewController class]] &&
             "loadControllerTo:, top view controller is either nil or has a wrong type");
    
      NewsTableViewController * const nt = (NewsTableViewController *)navController.topViewController;
      nt.navigationItem.title = feedName;
      nt.feedStoreID = feedName;
      [nt.aggregator addFeedForURL : [NSURL URLWithString : feed]];
      nt.isTwitterFeed = isTwitterFeed;
   } else if (!isTwitterFeed) {
      navController = (MenuNavigationController *)[controller.storyboard instantiateViewControllerWithIdentifier :
                                                                         FeedTileViewControllerID];
      assert([navController.topViewController isKindOfClass : [NewsFeedViewController class]] &&
             "loadControllerTo:, top view controller is either nil or has a wrong type");
      NewsFeedViewController * const nt = (NewsFeedViewController *)navController.topViewController;
      nt.navigationItem.title = feedName;
      nt.feedStoreID = feedName;
      [nt.aggregator addFeedForURL : [NSURL URLWithString : feed]];
   } else {
      //twitter feed on iPad.
      //TODO: there is not view/controller for iPad at the moment.
      ShowErrorAlert(@"Not implemented", @"Close");
      return;//TODO: need a new view/controller for this.
   }

   if (controller.slidingViewController.topViewController)
      CancelConnections(controller.slidingViewController.topViewController);

   [controller.slidingViewController anchorTopViewOffScreenTo : ECRight animations : nil onComplete:^{
      CGRect frame = controller.slidingViewController.topViewController.view.frame;
      controller.slidingViewController.topViewController = navController;
      controller.slidingViewController.topViewController.view.frame = frame;
      [controller.slidingViewController resetTopView];
   }];
}

@end

//

@implementation PhotoSetProvider {
   NSDictionary *info;
   UIImage *categoryImage;
}

@synthesize categoryName;

//________________________________________________________________________________________
- (id) initWithDictionary : (NSDictionary *) anInfo
{
   assert(anInfo != nil && "initWithDictionary:, parameter 'anInfo' is nil");

   if (self = [super init]) {
      assert([anInfo[@"Url"] isKindOfClass : [NSString class]] &&
             "initWithDictionary:, 'Url' is not found or has a wrong type");
      assert([anInfo[@"Name"] isKindOfClass : [NSString class]] &&
             "initWithDictionary:, 'Name' is not found or has a wrong type");
      categoryName = (NSString *)anInfo[@"Name"];
      
      if (anInfo[@"Image name"]) {
         assert([anInfo[@"Image name"] isKindOfClass : [NSString class]] &&
                "initWithDictionary:, 'Image name' is nil or has a wrong type");
         categoryImage = [UIImage imageNamed : (NSString *)anInfo[@"Image name"]];
      }
      
      info = anInfo;
   }
   
   return self;
}

//________________________________________________________________________________________
- (UIImage *) categoryImage
{
   return categoryImage;
}

//________________________________________________________________________________________
- (void) loadControllerTo : (UIViewController *) controller
{
   assert(controller != nil && "loadControllerTo:, parameter 'controller' is nil");
   
   using namespace CernAPP;
   
   //TODO: remove if/else part as soon as PhotosCollectionViewController is ready for both iPad/iPhone.
   
   MenuNavigationController *navController = nil;
   
   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
      navController = (MenuNavigationController *)[controller.storyboard instantiateViewControllerWithIdentifier : PhotoGridControllerNavID];
      assert([navController.topViewController isKindOfClass : [PhotosGridViewController class]] &&
              "loadControllerTo:, top view controller is either nil or has a wrong type");

      PhotosGridViewController * const topController = (PhotosGridViewController *)navController.topViewController;
      topController.photoDownloader.url = [NSURL URLWithString : (NSString *)info[@"Url"]];
      topController.navigationItem.title = categoryName;
   } else {
      navController = (MenuNavigationController *)[controller.storyboard instantiateViewControllerWithIdentifier : PhotoCollectionsViewControllerID];
      assert([navController.topViewController isKindOfClass : [PhotoCollectionsViewController class]] &&
             "loadControllerTo:, top view controller is either nil or has a wrong type");

      PhotoCollectionsViewController * const topController = (PhotoCollectionsViewController *)navController.topViewController;
      [topController setURL : [NSURL URLWithString : (NSString *)info[@"Url"]]];
      topController.navigationItem.title = categoryName;
   }

   if (controller.slidingViewController.topViewController)
      CancelConnections(controller.slidingViewController.topViewController);

   [controller.slidingViewController anchorTopViewOffScreenTo : ECRight animations : nil onComplete:^{
      CGRect frame = controller.slidingViewController.topViewController.view.frame;
      controller.slidingViewController.topViewController = navController;
      controller.slidingViewController.topViewController.view.frame = frame;
      [controller.slidingViewController resetTopView];
   }];

}

@end

@implementation LiveEventsProvider {
   NSMutableArray *liveEvents;
   CernAPP::LHCExperiment experiment;
}

@synthesize categoryName;

//________________________________________________________________________________________
- (CGRect) readImageBounds : (NSDictionary *) dict
{
   assert(dict != nil && "readImageBounds:, parameter 'dict' is nil");

   CGRect imageRect = {};
   
   id base = [dict objectForKey : @"cropX"];
   assert([base isKindOfClass : [NSNumber class]] &&
          "readImageBounds, object for the key 'cropX' not found or not an NSNumber");
   imageRect.origin.x = [(NSNumber *)base integerValue];//take as floating point number?
   
   base = [dict objectForKey : @"cropY"];
   assert([base isKindOfClass : [NSNumber class]] &&
          "readImageBounds, object for the key 'cropY' not found or not an NSNumber");
   imageRect.origin.y = [(NSNumber *)base integerValue];//take as floating point number?

   base = [dict objectForKey : @"cropW"];
   assert([base isKindOfClass : [NSNumber class]] &&
          "readImageBounds, object for the key 'cropW' not found or not an NSNumber");
   imageRect.size.width = [(NSNumber *)base integerValue];//take as floating point number?

   base = [dict objectForKey : @"cropH"];
   assert([base isKindOfClass : [NSNumber class]] &&
          "readImageBounds, object for the key 'cropH' not found or not an NSNumber");
   imageRect.size.height = [(NSNumber *)base integerValue];//take as floating point number?

   assert(imageRect.size.width > 0 && imageRect.size.height > 0 &&
          "readImageBounds, invalid image rectangle");

   return imageRect;
}

//________________________________________________________________________________________
- (void) readSingleImage : (NSDictionary *) imageDict
{
   assert(imageDict != nil && "readSingleImage:, parameter 'imageDict' is nil");
   assert(liveEvents != nil && "readSingleImage:, liveEvents is nil");
   assert([[imageDict objectForKey : @"Name"] isKindOfClass : [NSString class]] &&
          "readSingleImage:, object for key 'Name' not found or not of NSString type");
   assert([[imageDict objectForKey : @"Image"] isKindOfClass : [NSString class]] &&
          "readSingleImage:, object for key 'Image' not found or not of NSString type");
   
   CGRect imageBounds = {};
   
   //Let's check, if we have to crop an image.
   if (id obj = [imageDict objectForKey : @"Bounds"]) {
      assert([obj isKindOfClass : [NSDictionary class]] &&
             "readSingleImage:, object for key 'Bounds' must be a dictionary");
      
      imageBounds = [self readImageBounds : (NSDictionary *)obj];
   }
   
   LiveImageData *imageData = [[LiveImageData alloc] initWithName : (NSString *)[imageDict objectForKey : @"Name"]
                                                     url : (NSString *)[imageDict objectForKey : @"Image"]
                                                     bounds : imageBounds];
   [liveEvents addObject : imageData];
}

//________________________________________________________________________________________
- (void) readImageSet : (NSDictionary *) imageDict
{
   assert(imageDict != nil && "readImageSet:, parameter 'imageDict' is nil");
   assert(liveEvents != nil && "readImageSet:, liveEvents is nil");
   
   id base = [imageDict objectForKey : @"nImages"];
   assert([base isKindOfClass:[NSNumber class]] &&
          "readImageSet, object for key 'nImages' not found or is not a NSNumber");
   const NSInteger nImages = [(NSNumber *)base integerValue];
   assert(nImages > 0 && "readImageSet:, nImages must be a positive number");
   
   base = [imageDict objectForKey : @"Bounds"];
   assert([base isKindOfClass : [NSArray class]] &&
          "readImageSet, object for key 'Bounds' not found or is not a NSArray");
   NSArray * const bounds = (NSArray *)base;
   
   base = [imageDict objectForKey : @"Names"];
   assert([base isKindOfClass : [NSArray class]] &&
          "readImageSet, object for key 'Names' not found or is not a NSArray");
   NSArray * const names = (NSArray *)base;

   assert([names count] == [bounds count] && [names count] == nImages &&
          "readImageSet, inconsistent number of elements and bounds/names");
   
   base = [imageDict objectForKey : @"Image"];
   assert([base isKindOfClass : [NSString class]] &&
          "readImageSet, object for key 'Image' not found or not a NSString");

   NSString * const url = (NSString *)base;
   
   NSMutableArray *imageSet = [[NSMutableArray alloc] init];
   for (NSInteger i = 0; i < nImages; ++i) {
      base = [bounds objectAtIndex : i];
      assert([base isKindOfClass : [NSDictionary class]] &&
             "readImageSet:, image bounds must be NSDictionary");
      
      const CGRect imageBounds = [self readImageBounds : (NSDictionary *)base];
      assert([[names objectAtIndex : i] isKindOfClass : [NSString class]] &&
             "readImageSet:, sub-image names must be a NSString");

      LiveImageData * imageData = [[LiveImageData alloc] initWithName : (NSString *)[names objectAtIndex : i]
                                                         url : url bounds : imageBounds];
      [imageSet addObject : imageData];
   }
   
   [liveEvents addObject : imageSet];
}

//________________________________________________________________________________________
- (id) initWith : (NSArray *) images forExperiment : (CernAPP::LHCExperiment) e
{
   using namespace CernAPP;

   assert(images != nil && "initWith:, parameter 'images' is nil");
   
   if (self = [super init]) {
      categoryName = @"Live Events";//Probably, will be reset externally.
      liveEvents = [[NSMutableArray alloc] init];
   
      for (id base in images) {
         assert([base isKindOfClass : [NSDictionary class]] &&
                "initWith:forExperiment:, array of dictionaries expected");
         
         NSDictionary * const data = (NSDictionary *)base;
         assert([[data objectForKey : @"Category name"] isKindOfClass : [NSString class]] &&
                "initWith:forExperiment:, object for 'Category name' not found or is not of NSString type");

         NSString * const cat = (NSString *)[data objectForKey : @"Category name"];
         if ([cat isEqualToString : @"SingleImage"])
            [self readSingleImage : data];
         else if ([cat isEqualToString : @"ImageSet"])
            [self readImageSet : data];
         else {
            assert(0 && "initWith:forExperiment:, unknown type of entry found");
         }
      }
      
      experiment = e;
   }
   
   return self;
}

//________________________________________________________________________________________
- (UIImage *) categoryImage
{
   return nil;
}

//________________________________________________________________________________________
- (void) addSourceFor : (LiveImageData *) liveData intoController : (EventDisplayViewController *) controller
{
   assert(liveData != nil && "addSourceFor:intoController:, parameter 'data' is nil");
   assert(controller != nil && "addSourceFor:intoController:, parameter 'controller' is nil");
   
   if (liveData.bounds.size.width) {
      NSDictionary * const dict = [NSDictionary dictionaryWithObjectsAndKeys : [NSValue valueWithCGRect : liveData.bounds],
                                                                               @"Rect", liveData.imageName, @"Description", nil];
      NSArray * const imageData = [NSArray arrayWithObject : dict];
      [controller addSourceWithDescription : nil URL : [NSURL URLWithString : liveData.url] boundaryRects : imageData];
   } else {
      [controller addSourceWithDescription : liveData.imageName URL : [NSURL URLWithString : liveData.url] boundaryRects : nil];
   }
}

//________________________________________________________________________________________
- (void) addLiveImageDescription : (id) obj into : (EventDisplayViewController *) evc
{
   assert(obj != nil && "addLiveImageDescription:into:, parameter 'obj' is nil");
   assert(evc != nil && "addLiveImageDescription:into:, parameter 'evc' is nil");
   
   if ([obj isKindOfClass : [LiveImageData class]])
      [self addSourceFor : (LiveImageData *)obj intoController : evc];
   else {
      assert([obj isKindOfClass : [NSArray class]] && "addLiveImageDescription:into, unknown object");
      NSArray * const imageSet = (NSArray *)obj;
      assert(imageSet.count && "addLiveImageDescription:into:, imageSet is empty");
      
      NSMutableArray * const imageDescriptions = [[NSMutableArray alloc] init];
      for (LiveImageData * liveData in imageSet) {
         NSDictionary * const imageDict = [NSDictionary dictionaryWithObjectsAndKeys :
                                                        [NSValue valueWithCGRect : liveData.bounds], @"Rect",
                                                        liveData.imageName, @"Description", nil];
         [imageDescriptions addObject : imageDict];
      }
      
      LiveImageData * const liveData = (LiveImageData *)[imageSet objectAtIndex : 0];
      [evc addSourceWithDescription : nil URL : [NSURL URLWithString : liveData.url] boundaryRects : imageDescriptions];
   }
}

//________________________________________________________________________________________
- (void) loadControllerTo : (UIViewController *) controller
{
   using namespace CernAPP;

   assert(controller != nil && "loadControllerTo:, parameter controller is nil");
   
   
   NSString * const experimentName = [NSString stringWithFormat : @"%s", ExperimentName(experiment)];
   MenuNavigationController *navController = nil;
 
   if ([liveEvents count] == 1 && [[liveEvents objectAtIndex : 0] isKindOfClass : [LiveImageData class]]) {
      //For such an image we just load "event display" view directly into the navigation controller.
      navController = (MenuNavigationController *)[controller.storyboard instantiateViewControllerWithIdentifier : EventDisplayControllerID];
      //
      assert([navController.topViewController isKindOfClass : [EventDisplayViewController class]] &&
             "loadControllerTo:, top view controller is either nil or has a wrong type");
      
      EventDisplayViewController * const evc = (EventDisplayViewController *)navController.topViewController;
      [self addLiveImageDescription : liveEvents[0] into : evc];
      //Combine experiment name and category name?
      evc.title = categoryName;
   } else {
      //TODO: there is not view/controller for iPad at the moment.
      if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
         navController = (MenuNavigationController *)[controller.storyboard instantiateViewControllerWithIdentifier : EventDisplayControllerID];
         assert([navController.topViewController isKindOfClass : [EventDisplayViewController class]] &&
                "loadControllerTo:, top view controller is either nil or has a wrong type");
      
         EventDisplayViewController * const evc = (EventDisplayViewController *)navController.topViewController;
         for (id obj in liveEvents)
            [self addLiveImageDescription : obj into : evc];

         evc.title = [NSString stringWithFormat : @"%s", ExperimentName(experiment)];
      } else {//On iPhone we have an intermediate table.
         navController = (MenuNavigationController *)[controller.storyboard instantiateViewControllerWithIdentifier : EventDisplayControllerFromTableID];
         assert([navController.topViewController isKindOfClass : [LiveEventTableController class]] &&
                "loadControllerTo:, top view controller is either nil or has a wrong type");

         LiveEventTableController * const eventViewController = (LiveEventTableController *)navController.topViewController;
         
         eventViewController.navigationItem.title = categoryName;

         [eventViewController setTableContents : liveEvents experimentName : experimentName];
         eventViewController.provider = self;
         eventViewController.navController = navController;
      }
   }
   
   if (controller.slidingViewController.topViewController)
      CancelConnections(controller.slidingViewController.topViewController);
   
   [controller.slidingViewController anchorTopViewOffScreenTo : ECRight animations : nil onComplete:^{
      CGRect frame = controller.slidingViewController.topViewController.view.frame;
      controller.slidingViewController.topViewController = navController;
      controller.slidingViewController.topViewController.view.frame = frame;
      [controller.slidingViewController resetTopView];
   }];
}

//________________________________________________________________________________________
- (void) pushEventDisplayInto : (UINavigationController *) controller selectedImage : (NSInteger) selected
{
   assert(controller != nil && "pushEventDisplayInto:selectedImage:, parameter 'controller' is nil");
   assert(selected >= 0 && "pushEventDisplayInto:selectedImage:, parameter 'selected' is negative");

   using namespace CernAPP;
 
   UIStoryboard * const mainStoryboard = [UIStoryboard storyboardWithName : @"iPhone" bundle : nil];
   EventDisplayViewController * const evc = [mainStoryboard instantiateViewControllerWithIdentifier : EventDisplayControllerNavID];
   
   for (id obj in liveEvents)
      [self addLiveImageDescription : obj into : evc];

   evc.title = [NSString stringWithFormat : @"%s", ExperimentName(experiment)];
   [controller pushViewController : evc animated : YES];
   
   if (selected)
      [evc scrollToPage : selected];
}

@end

@implementation LiveImageData

@synthesize imageName, url, image,bounds;

//________________________________________________________________________________________
- (id) initWithName : (NSString *) name url : (NSString *) imageUrl bounds : (CGRect) imageBounds
{
   if (self = [super init]) {
      imageName = name;
      url = imageUrl;
      image = nil;//to be loaded yet!
      bounds = imageBounds;
   }
   
   return self;
}

@end

//

@implementation BulletinProvider {
   UIImage *menuImage;
   NSString *url;
}

@synthesize categoryName;

//________________________________________________________________________________________
- (id) initWithDictionary : (NSDictionary *) info
{
   assert(info != nil && "initWithDictionary:, parameter 'info' is nil");

   if (self = [super init]) {
      categoryName = @"Bulletin";
      
      if (info[@"Image"]) {
         assert([info[@"Image"] isKindOfClass : [NSString class]] &&
                "initWithDictionary:, value for the key 'Image' must be an NSString");
         menuImage = [UIImage imageNamed:(NSString *)info[@"Image"]];
      }
      
      assert([info[@"Url"] isKindOfClass : [NSString class]] &&
             "initWithDictionary:, 'Url' not found or has a wrong type");
      url = (NSString *)info[@"Url"];
   }
   
   return self;
}

//________________________________________________________________________________________
- (UIImage *) categoryImage
{
   return menuImage;
}

//________________________________________________________________________________________
- (void) loadControllerTo : (UIViewController *) controller
{
   assert(controller != nil && "loadControllerTo:, parameter 'controller' is nil");

   using namespace CernAPP;
   
   MenuNavigationController *navController = nil;
   
   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
      navController = (MenuNavigationController *)[controller.storyboard instantiateViewControllerWithIdentifier :
                                                                         BulletinTileViewControllerID];
      assert([navController.topViewController isKindOfClass : [BulletinFeedViewController class]] &&
             "loadControllerTo:, top view controller is either nil or has a wrong type");
      BulletinFeedViewController * const nt = (BulletinFeedViewController *)navController.topViewController;
      nt.feedStoreID = @"CERN_Bulletin";
      [nt.aggregator addFeedForURL : [NSURL URLWithString : url]];
   } else {
      navController = (MenuNavigationController *)[controller.storyboard instantiateViewControllerWithIdentifier : BulletinTableViewControllerID];
      //Set the Url here.
      assert([navController.topViewController isKindOfClass : [BulletinTableViewController class]] &&
             "loadControllerTo:, top view controller expected to be a BulletinTableViewController");
      BulletinTableViewController * const bc = (BulletinTableViewController *)navController.topViewController;
      [bc.aggregator addFeedForURL : [NSURL URLWithString : url]];
   }
   
   navController.topViewController.navigationItem.title = @"Bulletin";

   if (controller.slidingViewController.topViewController)
      CancelConnections(controller.slidingViewController.topViewController);

   [controller.slidingViewController anchorTopViewOffScreenTo : ECRight animations : nil onComplete:^{
      CGRect frame = controller.slidingViewController.topViewController.view.frame;
      controller.slidingViewController.topViewController = navController;
      controller.slidingViewController.topViewController.view.frame = frame;
      [controller.slidingViewController resetTopView];
   }];
}

@end

@implementation StaticInfoProvider {
   NSDictionary *info;
}

//________________________________________________________________________________________
- (id) initWithDictionary : (NSDictionary *) dict
{
   assert(dict != nil && "initWithDictionary:, parameter 'info' is nil");

   if (self = [super init]) {
      assert([dict[@"Title"] isKindOfClass : [NSString class]] &&
             "initWithDictionary:, 'Title' is not found or has a wrong type");
      assert([dict[@"Items"] isKindOfClass : [NSArray class]] &&
             "initWithDictionary:, 'Items' is not found or has a wrong type");
      info = dict;
   }
   
   return self;
}

//________________________________________________________________________________________
- (NSString *) categoryName
{
   return (NSString *)info[@"Title"];
}

//________________________________________________________________________________________
- (UIImage *) categoryImage
{
   //Noop at the moment.
   return nil;
}

//________________________________________________________________________________________
- (void) loadControllerTo : (UIViewController *) controller
{
   assert(controller != nil && "loadControllerTo:, parameter 'controller' is nil");

   using namespace CernAPP;

   MenuNavigationController *navController = nil;
   
   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
      navController = (MenuNavigationController *)[controller.storyboard instantiateViewControllerWithIdentifier:
                                                                         StaticInfoTileViewControllerID];
      assert([navController.topViewController isKindOfClass : [StaticInfoTileViewController class]] &&
             "loadControllerTo:, top view controller is either nil or has a wrong type");
      
      StaticInfoTileViewController * const sc = (StaticInfoTileViewController *)navController.topViewController;
      sc.navigationItem.title = @"test";
      sc.navigationItem.title = (NSString *)info[@"Title"];      
      sc.dataSource = (NSArray *)info[@"Items"];
   } else {
      navController = (MenuNavigationController *)[controller.storyboard instantiateViewControllerWithIdentifier :
                                                                         StaticInfoNavigationControllerID];
      assert([navController.topViewController isKindOfClass : [StaticInfoScrollViewController class]] &&
             "loadControllerTo:, top view controller is either nil or has a wrong type");
      
      StaticInfoScrollViewController * const sc = (StaticInfoScrollViewController *)navController.topViewController;
      sc.navigationItem.title = (NSString *)info[@"Title"];
      sc.dataSource = (NSArray *)info[@"Items"];
   }
   
   if (controller.slidingViewController.topViewController)
      CancelConnections(controller.slidingViewController.topViewController);

   [controller.slidingViewController anchorTopViewOffScreenTo : ECRight animations : nil onComplete:^{
      CGRect frame = controller.slidingViewController.topViewController.view.frame;
      controller.slidingViewController.topViewController = navController;
      controller.slidingViewController.topViewController.view.frame = frame;
      [controller.slidingViewController resetTopView];
   }];
}

@end

//
//
//

@implementation LatestVideosProvider {
   UIImage *image;
}

@synthesize categoryName;

//________________________________________________________________________________________
- (id) initWithDictionary : (NSDictionary *) info
{
   assert(info != nil && "initWithDictionary:, parameter 'info' is nil");
   
   if (self = [super init]) {
      assert([info[@"Name"] isKindOfClass : [NSString class]] &&
             "initWithDictionary, 'Name' not found or has a wrong type");
      categoryName = (NSString *)info[@"Name"];
      if (info[@"Image name"]) {
         assert([info[@"Image name"] isKindOfClass : [NSString class]] &&
                "initWithDictionary:, 'Image name' has a wrong type");
         image = [UIImage imageNamed : (NSString *)info[@"Image name"]];
      }
   }
   
   return self;
}

//________________________________________________________________________________________
- (UIImage *) categoryImage
{
   return image;
}

//________________________________________________________________________________________
- (void) loadControllerTo : (UIViewController *) controller
{
   assert(controller != nil && "loadControllerTo:, parameter 'controller' is nil");
   
   using namespace CernAPP;
   
   MenuNavigationController * const navController =
                  (MenuNavigationController *)[controller.storyboard instantiateViewControllerWithIdentifier :
                                                                     VideoCollectionsViewControllerID];

   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
      assert([navController.topViewController isKindOfClass : [VideosCollectionViewController class]] &&
             "loadControllerTo:, top view controller is either nil or has a wrong type");
      //Some additional setup here?.
   
   } else {
      assert([navController.topViewController isKindOfClass : [VideosGridViewController class]] &&
             "loadControllerTo:, top view controller is either nil or has a wrong type");
      //Some additional setup here?.
   }

   UIViewController * const vc = navController.topViewController;
   vc.navigationItem.title = categoryName;
   
   if (controller.slidingViewController.topViewController)
      CancelConnections(controller.slidingViewController.topViewController);

   [controller.slidingViewController anchorTopViewOffScreenTo : ECRight animations : nil onComplete:^{
      CGRect frame = controller.slidingViewController.topViewController.view.frame;
      controller.slidingViewController.topViewController = navController;
      controller.slidingViewController.topViewController.view.frame = frame;
      [controller.slidingViewController resetTopView];
   }];
}

@end

@implementation ModalViewProvider {
   UIImage *image;
   NSString *controllerID;
}

@synthesize categoryName;

//________________________________________________________________________________________
- (id) initWithDictionary : (NSDictionary *) info
{
   assert(info != nil && "initWithDictionary:, parameter 'info' is nil");
   
   if (self = [super init]) {
      assert([info[@"Name"] isKindOfClass : [NSString class]] &&
             "initWithDictionary:, 'Name' is nil or has a wrong type");
      categoryName = (NSString *)info[@"Name"];
      
      if (info[@"Image name"]) {
         assert([info[@"Image name"] isKindOfClass : [NSString class]] &&
                "initWithDictionary:, 'Image name' has a wrong type");
         image = [UIImage imageNamed : (NSString *)info[@"Image name"]];
      }
      
      assert([info[@"ControllerID"] isKindOfClass : [NSString class]] &&
             "initWithDictionary:, 'ControllerID' is nil or has a wrong type");
      
      controllerID = (NSString *)info[@"ControllerID"];
   }
   
   return self;
}

//________________________________________________________________________________________
- (UIImage *) categoryImage
{
   return image;
}

//________________________________________________________________________________________
- (void) loadControllerTo : (UIViewController *) controller
{
   assert(controller != nil && "loadControllerTo:, parameter 'controller' is nil");
   
   using namespace CernAPP;
 
   UIViewController * const vc = [controller.storyboard instantiateViewControllerWithIdentifier : controllerID];
   [controller presentViewController : vc animated : YES completion : nil];
}

@end 

@implementation NavigationViewProvider {
   UIImage *image;
   NSString *controllerID;
   NSArray *itemData;
}

@synthesize categoryName;

//________________________________________________________________________________________
- (id) initWithDictionary : (NSDictionary *) dict
{
   assert(dict != nil && "initWithDictionary:, parameter 'dict' is nil");

   if (self = [super init]) {
      assert([dict[@"Name"] isKindOfClass : [NSString class]] &&
             "initWithDictionary:, 'Name' is nil or has a wrong type");
      categoryName = (NSString *)dict[@"Name"];
      
      if (dict[@"Image name"]) {
         assert([dict[@"Image name"] isKindOfClass : [NSString class]] &&
                "initWithDictionary:, 'Image name' has a wrong type");
         image = [UIImage imageNamed:(NSString *)dict[@"Image name"]];
      }
      
      if (dict[@"ItemData"]) {
         assert([dict[@"ItemData"] isKindOfClass : [NSArray class]] &&
                "initWithDictionary:, 'ItemData' has a wrong type");
         itemData = (NSArray *)dict[@"ItemData"];
      } else
         itemData = nil;
      
      assert([dict[@"ControllerID"] isKindOfClass : [NSString class]] &&
             "'ControllerID' not found or has a wrong type");
      controllerID = (NSString *)dict[@"ControllerID"];
   }
   
   return self;
}

- (UIImage *) categoryImage
{
   return image;
}

//________________________________________________________________________________________
- (void) loadControllerTo : (UIViewController *) controller
{
   //TODO: there is no view/controller for iPad at the moment.

   assert(controller != nil && "loadControllerTo:, parameter 'controller' is nil");
   
   MenuNavigationController *navController = [controller.storyboard instantiateViewControllerWithIdentifier : controllerID];
   if (controller.slidingViewController.topViewController)
      CancelConnections(controller.slidingViewController.topViewController);

   if (itemData && [navController.topViewController respondsToSelector:@selector(setControllerData:)])
      [navController.topViewController performSelector : @selector(setControllerData:) withObject : itemData];

   [controller.slidingViewController anchorTopViewOffScreenTo : ECRight animations : nil onComplete : ^ {
      CGRect frame = controller.slidingViewController.topViewController.view.frame;
      controller.slidingViewController.topViewController = navController;
      controller.slidingViewController.topViewController.view.frame = frame;
      [controller.slidingViewController resetTopView];
   }];
}

@end
