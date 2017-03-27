//
//  GUIHelpers.m
//  ECSlidingViewController
//
//  Created by Timur Pocheptsov on 1/1/13.
//
//

#import <cassert>

#import "GUIHelpers.h"

namespace CernAPP {

const CGFloat spinnerSize = 150.f;
const CGSize navBarBackButtonSize  = CGSizeMake(35.f, 35.f);
const CGFloat navBarHeight = 44.f;

//Menu.

const CGFloat childMenuItemTextIndent = 15.f;

NSString * const childMenuFontName = @"PTSans-Caption";
NSString * const groupMenuFontName = @"PTSans-Bold";
const CGFloat groupMenuItemImageHeight = 24.f;
const CGFloat childMenuItemImageHeight = 15.f;
const CGFloat childTextColor[] = {0.772f, 0.796f, 0.847f};
const CGFloat menuColor[4] = {0.215f, 0.231f, 0.29f, 1.f};
const CGFloat menuItemHighlightColor[4] = {0.f, 0.564f, 0.949f, 1.f};
const CGFloat groupItemColor[4] = {0.2f, 0.216, 0.275, 1.f};
const CGFloat menuWidthPad = 320.f;

//________________________________________________________________________________________
CGFloat GroupMenuItemHeight()
{
   return 44.f;
}

//________________________________________________________________________________________
CGFloat ChildMenuItemHeight()
{
   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
      return 40.f;

   return 30.f;
}

//________________________________________________________________________________________
CGFloat SeparatorItemHeight()
{
   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
      return 25.f;

   return 20.f;
}

//________________________________________________________________________________________
void GradientFillRect(CGContextRef ctx, const CGRect &rect, const CGFloat *gradientColor)
{
   //Simple gradient, two colors only.

   assert(ctx != nullptr && "GradientFillRect, parameter 'ctx' is null");
   assert(gradientColor != nullptr && "GradientFillRect, parameter 'gradientColor' is null");
   
   const CGPoint startPoint = CGPointZero;
   const CGPoint endPoint = CGPointMake(0.f, rect.size.height);
      
   //Create a gradient.
   CGColorSpaceRef baseSpace(CGColorSpaceCreateDeviceRGB());
   const CGFloat positions[] = {0.f, 1.f};//Always fixed.

   CGGradientRef gradient(CGGradientCreateWithColorComponents(baseSpace, gradientColor, positions, 2));//fixed, 2 colors only.
   CGContextDrawLinearGradient(ctx, gradient, startPoint, endPoint, 0);
      
   CGGradientRelease(gradient);
   CGColorSpaceRelease(baseSpace);
}

}
