#import <cassert>

#import <UIKit/UIKit.h>

#import "ApplicationErrors.h"

namespace CernAPP
{

//________________________________________________________________________________________
void ShowErrorAlert(NSString *message, NSString *buttonTitle)
{
   assert(message != nil && "ShowErrorAlert, parameter 'message' is nil");
   assert(buttonTitle != nil && "ShowErrorAlert, parameter 'buttonTitle' is nil");

   UIAlertView * const alert = [[UIAlertView alloc] initWithTitle : @"CERN" message : message
                                delegate : nil cancelButtonTitle : buttonTitle otherButtonTitles : nil];
   [alert show];
}

}