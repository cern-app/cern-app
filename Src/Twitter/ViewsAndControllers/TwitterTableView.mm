#import "TwitterTableViewController.h"
#import "TwitterTableView.h"

@implementation TwitterTableView {
   BOOL endUpdatesCalled;
}

@synthesize animatingSelection;

//________________________________________________________________________________________
- (void) endUpdates
{
   [super endUpdates];
   endUpdatesCalled = YES;
}

//________________________________________________________________________________________
- (void) setContentSize:(CGSize)contentSize
{
   [super setContentSize:contentSize];
   
   if (endUpdatesCalled) {
      endUpdatesCalled = NO;
      
      if (animatingSelection) {
         if ([self.delegate isKindOfClass:[TwitterTableViewController class]])
            [(TwitterTableViewController *)self.delegate cellAnimationFinished];
         animatingSelection = NO;
      }
   }
}


@end
