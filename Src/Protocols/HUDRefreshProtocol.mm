//
//  HUDRefreshProtocol.m
//  CERN
//
//  Created by Timur Pocheptsov on 2/25/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <cassert>

#import "ActivityIndicatorView.h"
#import "HUDRefreshProtocol.h"
#import "GUIHelpers.h"

namespace CernAPP {

//________________________________________________________________________________________
void AddSpinner(UIViewController<HUDRefreshProtocol> *controller)
{
   assert(controller != nil && "AddSpinner, parameter 'controller' is nil");

   controller.spinner = AddSpinner(controller.view);
}

//________________________________________________________________________________________
void AddCustomSpinner(UIViewController<HUDRefreshProtocol> *controller)
{
   assert(controller != nil && "AddCustomSpinner, parameter 'controller' is nil");
   
   controller.spinner = AddSpinner(controller.view, true);
}

//________________________________________________________________________________________
UIActivityIndicatorView *AddSpinner(UIView *parentView, bool custom)
{
   assert(parentView != nil && "AddSpinner, parameter 'parentView' is nil");

   const CGPoint spinnerOrigin = CGPointMake(parentView.frame.size.width / 2 - spinnerSize / 2, parentView.frame.size.height / 2 - spinnerSize / 2);

   UIActivityIndicatorView *spinner = nil;
   
   if (!custom)
      spinner = [[UIActivityIndicatorView alloc] initWithFrame : CGRectMake(spinnerOrigin.x, spinnerOrigin.y, spinnerSize, spinnerSize)];
   else
      spinner = [[ActivityIndicatorView alloc] initWithFrame : CGRectMake(spinnerOrigin.x, spinnerOrigin.y, spinnerSize, spinnerSize)];

   spinner.color = [UIColor grayColor];
   
  // if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
      spinner.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight |
                                 UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
                                 UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
//   }
   
   [parentView addSubview : spinner];

   return spinner;
}

//________________________________________________________________________________________
void ShowSpinner(UIViewController<HUDRefreshProtocol> *controller)
{
   assert(controller != nil && "ShowSpinner, parameter 'controller' is nil");
   assert(controller.spinner != nil && "ShowSpinner, controller.spinner is nil");

   ShowSpinner(controller.spinner);
}

//________________________________________________________________________________________
void ShowSpinner(UIActivityIndicatorView *spinner)
{
   assert(spinner != nil && "ShowSpinner, parameter 'spinner' is nil");
   
   if (spinner.hidden)
      spinner.hidden = NO;
   if (!spinner.isAnimating)
      [spinner startAnimating];
   
   //Hahahah, I like this laja.hlam.shlak.musor :)
   if (spinner.superview.subviews.lastObject != spinner)
      [spinner.superview bringSubviewToFront : spinner];
}

//________________________________________________________________________________________
void HideSpinner(UIViewController<HUDRefreshProtocol> *controller)
{
   assert(controller != nil && "HideSpinner, parameter 'controller' is nil");
   assert(controller.spinner != nil && "HideSpinner, controller.spinner is nil");

   HideSpinner(controller.spinner);
}

//________________________________________________________________________________________
void HideSpinner(UIActivityIndicatorView *spinner)
{
   assert(spinner != nil && "HideSpinner, parameter 'spinner' is nil");
   
   if (spinner.isAnimating)
      [spinner stopAnimating];
   spinner.hidden = YES;
}

//________________________________________________________________________________________
void ShowErrorHUD(UIViewController<HUDRefreshProtocol> *controller, NSString *errorMessage)
{
   assert(controller != nil && "ShowErrorHUD, parameter 'controller' is nil");
   assert(errorMessage != nil && "ShowErrorHUD, parameter 'errorMessage' is nil");

   controller.noConnectionHUD = ShowErrorHUD(controller.view, errorMessage);
}

//________________________________________________________________________________________
MBProgressHUD *ShowErrorHUD(UIView *parentView, NSString *errorMessage)
{
   assert(parentView != nil && "ShowErrorHUD, parameter 'parentView' is nil");
   assert(errorMessage != nil && "ShowErrorHUD, parameter 'errorMessage' is nil");

   [MBProgressHUD hideHUDForView : parentView animated : YES];

   MBProgressHUD * const noConnectionHUD = [MBProgressHUD showHUDAddedTo : parentView animated : YES];
   noConnectionHUD.color = [UIColor redColor];
   noConnectionHUD.mode = MBProgressHUDModeText;
   noConnectionHUD.labelText = errorMessage;
   noConnectionHUD.removeFromSuperViewOnHide = YES;

   return noConnectionHUD;
}

//________________________________________________________________________________________
MBProgressHUD *ShowInfoHUD(UIView *parentView, NSString *infoMessage)
{
   assert(parentView != nil && "ShowInfoHUD, parameter 'parentView' is nil");
   assert(infoMessage != nil && "ShowInfoHUD, parameter 'infoMessage' is nil");
   
   [MBProgressHUD hideHUDForView : parentView animated : YES];
   
   MBProgressHUD * const infoHUD = [MBProgressHUD showHUDAddedTo : parentView animated : YES];
   infoHUD.color = [UIColor colorWithRed : 0.f green : 83.f / 255.f blue : 161.f / 255.f alpha : 1.f];
   infoHUD.mode = MBProgressHUDModeText;
   infoHUD.labelText = infoMessage;
   infoHUD.removeFromSuperViewOnHide = YES;

   return infoHUD;

}

}
