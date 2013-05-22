//
//  HUDRefreshProtocol.m
//  CERN
//
//  Created by Timur Pocheptsov on 2/25/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <cassert>

#import "HUDRefreshProtocol.h"
#import "GUIHelpers.h"

namespace CernAPP {

//________________________________________________________________________________________
void AddSpinner(UIViewController<HUDRefreshProtocol> *controller)
{
   assert(controller != nil && "AddSpinner, parameter 'controller' is nil");

   using CernAPP::spinnerSize;



   const CGPoint spinnerOrigin = CGPointMake(controller.view.frame.size.width / 2 - spinnerSize / 2, controller.view.frame.size.height / 2 - spinnerSize / 2);

   UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithFrame : CGRectMake(spinnerOrigin.x, spinnerOrigin.y, spinnerSize, spinnerSize)];
   spinner.color = [UIColor grayColor];
   
   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
      spinner.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight |
                                 UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
                                 UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
   }
   
   [controller.view addSubview : spinner];
   controller.spinner = spinner;
}

//________________________________________________________________________________________
void ShowSpinner(UIViewController<HUDRefreshProtocol> *controller)
{
   assert(controller != nil && "ShowSpinner, parameter 'controller is nil");

   if (controller.spinner.hidden)
      controller.spinner.hidden = NO;
   if (!controller.spinner.isAnimating)
      [controller.spinner startAnimating];
   
   //Hahahah, I like this laja.hlam.shlak.musor :)
   if (controller.spinner.superview.subviews.lastObject != controller.spinner)
      [controller.spinner.superview bringSubviewToFront : controller.spinner];
}

//________________________________________________________________________________________
void HideSpinner(UIViewController<HUDRefreshProtocol> *controller)
{
   assert(controller != nil && "HideSpinner, parameter 'controller' is nil");
   
   if (controller.spinner.isAnimating)
      [controller.spinner stopAnimating];
   controller.spinner.hidden = YES;
}

//________________________________________________________________________________________
void ShowErrorHUD(UIViewController<HUDRefreshProtocol> *controller, NSString *errorMessage)
{
   assert(controller != nil && "ShowErrorHUD, parameter 'controller' is nil");
   assert(errorMessage != nil && "ShowErrorHUD, parameter 'errorMessage' is nil");

   [MBProgressHUD hideHUDForView : controller.view animated : YES];

   MBProgressHUD *noConnectionHUD = [MBProgressHUD showHUDAddedTo : controller.view animated : YES];
   noConnectionHUD.color = [UIColor redColor];
   noConnectionHUD.mode = MBProgressHUDModeText;
   noConnectionHUD.labelText = @"Network error";
   noConnectionHUD.removeFromSuperViewOnHide = YES;
   controller.noConnectionHUD = noConnectionHUD;
}

}