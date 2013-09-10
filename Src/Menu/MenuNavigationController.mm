#import <cassert>

#import "StaticInfoScrollViewController.h"
#import "ArticleDetailViewController.h"
#import "MenuNavigationController.h"
#import "NewsTableViewController.h"
#import "ECSlidingViewController.h"
#import "MenuViewController.h"

//This controller is a base for all other controllers we load into the
//sliding view controller (except trivial event displays, like CMS DAQ, etc.).

@implementation MenuNavigationController

//________________________________________________________________________________________
- (id) initWithNibName : (NSString *) nibNameOrNil bundle : (NSBundle *) nibBundleOrNil
{
   return self = [super initWithNibName : nibNameOrNil bundle : nibBundleOrNil];
}

//________________________________________________________________________________________
- (void) viewDidLoad
{
   [super viewDidLoad];
	//Do any additional setup after loading the view.
}

//________________________________________________________________________________________
- (void) didReceiveMemoryWarning
{
   [super didReceiveMemoryWarning];
   //Dispose of any resources that can be recreated.
}

//________________________________________________________________________________________
- (void) viewWillAppear : (BOOL) animated
{
   [super viewWillAppear : animated];
  
   //We need a nice smooth shadow under our table.
   self.view.layer.shadowOpacity = 0.75f;
   self.view.layer.shadowRadius = 10.f;
   self.view.layer.shadowColor = [UIColor blackColor].CGColor;
  
   if (![self.slidingViewController.underLeftViewController isKindOfClass : [MenuViewController class]])
      self.slidingViewController.underLeftViewController  = [self.storyboard instantiateViewControllerWithIdentifier : @"Menu"];

   [self.view addGestureRecognizer : self.slidingViewController.panGesture];
}

#pragma mark - Interface orientation.

//________________________________________________________________________________________
- (BOOL) shouldAutorotate
{
   return [self.topViewController shouldAutorotate];
}

//________________________________________________________________________________________
- (NSUInteger) supportedInterfaceOrientations
{
   return [self.topViewController supportedInterfaceOrientations];
}

#pragma mark - ConnectionController.

//________________________________________________________________________________________
- (void) cancelAnyConnections
{
   //Cancel all connections in the reversed range [top, self).
   NSEnumerator * const enumerator = [self.viewControllers reverseObjectEnumerator];
   for (id controller in enumerator) {
      if ([controller respondsToSelector : @selector(cancelAnyConnections)])
         [controller performSelector : @selector(cancelAnyConnections)];
   }
}

//________________________________________________________________________________________
- (UIViewController *) popViewControllerAnimated : (BOOL) animated
{
   UIViewController * const controllerToPop = [super popViewControllerAnimated : animated];
   if ([controllerToPop isKindOfClass : [ArticleDetailViewController class]]) {
      [(ArticleDetailViewController *)controllerToPop cancelAnyConnections];
   }
   
   return controllerToPop;
}

#pragma mark - APNEnabledViewController.

//TODO: this part is a pure and quite ugly hack :(

//________________________________________________________________________________________
- (NSUInteger) apnID
{
   UIViewController * const next = self.viewControllers[0];
   if (next && [next conformsToProtocol : @protocol(APNEnabledController)])
      return ((UIViewController<APNEnabledController> *)next).apnID;

   return 0;//Hack, 0 is considered to be an invalid ID.
}

//________________________________________________________________________________________
- (void) addAPNItems : (NSUInteger) newItems
{
   UIViewController * const next = self.viewControllers[0];
   if (next && [next conformsToProtocol : @protocol(APNEnabledController)])
      [(UIViewController<APNEnabledController> *)next addAPNItems : newItems];
}

@end
