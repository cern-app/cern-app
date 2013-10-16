//Another stupid class to solve a stupid problem: activity indicator view "swallows" tap gestures???

#import "ActivityIndicatorView.h"

@implementation ActivityIndicatorView

//________________________________________________________________________________________
- (UIView *) hitTest : (CGPoint) point withEvent : (UIEvent *) event
{
#pragma unused(point, event)
   return nil;
}

@end
