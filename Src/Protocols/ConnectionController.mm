#import "ConnectionController.h"

namespace CernAPP
{

//________________________________________________________________________________________
void CancelConnections(UIViewController *controller)
{
   assert(controller != nil && "CancelConnections, parameter 'controller' is nil");

   if ([controller respondsToSelector : @selector(cancelAnyConnections)])
      [controller performSelector : @selector(cancelAnyConnections)];
}

}
