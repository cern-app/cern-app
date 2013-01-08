//
//  MenuItemViews.m
//  slide_menu
//
//  Created by Timur Pocheptsov on 1/7/13.
//  Copyright (c) 2013 Timur Pocheptsov. All rights reserved.
//

#import <cassert>

#import <QuartzCore/QuartzCore.h>

#import "MenuViewController.h"
#import "MenuItemViews.h"
#import "GUIHelpers.h"

//Menu GUI constants.
//It's a C++, all these constants have
//internal linkage without any 'static',
//and no need for unnamed namespace.
const CGFloat groupMenuItemFontSize = 17.f;
const CGFloat childMenuItemFontSize = 13.f;
NSString * const groupMenuFontName = @"PTSans-Bold";
NSString * const childMenuFontName = @"PTSans-Caption";
const CGSize menuTextShadowOffset = CGSizeMake(2.f, 2.f);
const CGFloat menuTextShadowAlpha = 0.5f;
const CGFloat menuItemImageSize = 24.f;//must be square image.
const CGFloat groupMenuItemTextIdent = 10.f;
const CGFloat groupMenuItemTextHeight = 20.f;
const CGFloat childMenuItemTextIdent = 20.f;
const CGFloat childMenuItemTextHeight = 20.f;
const CGFloat discloseTriangleSize = 14.f;
const CGFloat groupMenuItemLeftMargin = 80.f;

const CGFloat childMenuFillColor[] = {0.215f, 0.231f, 0.29f};
const CGFloat groupMenuFillColor[][4] = {{0.247f, 0.29f, 0.36f, 1.f}, {0.242f, 0.258f, 0.321f, 1.f}};
const CGFloat frameTopLineColor[] = {0.258f, 0.278f, 0.33f};
const CGFloat frameBottomLineColor[] = {0.165f, 0.18f, 0.227f};

const CGFloat childTextColor[] = {0.772f, 0.796f, 0.847f};
const CGFloat groupTextColor[] = {0.615f, 0.635f, 0.69f};

using CernAPP::ItemStyle;

namespace {

//________________________________________________________________________________________
void GradientFillRect(CGContextRef ctx, CGRect rect, const CGFloat *gradientColor)
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


@implementation MenuItemView {
   ItemStyle itemStyle;

   //Weak, we do not have to control life time of these objects.
   __weak NSObject<MenuItemProtocol> *menuItem;
   __weak MenuViewController *controller;

   UILabel *itemLabel;
}

@synthesize isSelected;

//________________________________________________________________________________________
- (id) initWithFrame : (CGRect) frame item : (NSObject<MenuItemProtocol> *) anItem
       style : (CernAPP::ItemStyle) aStyle controller : (MenuViewController *) aController
{
   assert(aStyle == ItemStyle::standalone || aStyle == ItemStyle::separator || aStyle == ItemStyle::child &&
          "initWithFrame:item:style:controller:, parameter 'aStyle' is invalid");
   assert(aStyle == ItemStyle::separator || anItem &&
          "initWithFrame:item:style:controller:, parameter 'anItem' is nil and style is not a separator");
   assert(aController != nil && "initWithFrame:item:style:controller:, parameter 'aController' is nil");

   if (self = [super initWithFrame : frame]) {
      menuItem = anItem;
      itemStyle = aStyle;
      controller = aController;
      
      if (aStyle != ItemStyle::separator) {//Separator is simply a blank row in a menu.
         UITapGestureRecognizer * const tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget : self action : @selector(handleTap)];
         [tapRecognizer setNumberOfTapsRequired : 1];
         [self addGestureRecognizer : tapRecognizer];
         
         itemLabel = [[UILabel alloc] initWithFrame : CGRect()];
         itemLabel.text = menuItem.itemText;

         UIFont * const font = [UIFont fontWithName : childMenuFontName size : childMenuItemFontSize];
         assert(font != nil && "initWithFrame:item:style:controller:, font not found");
         itemLabel.font = font;
      
         itemLabel.textAlignment = NSTextAlignmentLeft;
         itemLabel.numberOfLines = 1;
         itemLabel.clipsToBounds = YES;
         itemLabel.backgroundColor = [UIColor clearColor];
         itemLabel.textColor = [UIColor colorWithRed : childTextColor[0] green : childTextColor[1] blue : childTextColor[2] alpha : 1.f];

         [self addSubview : itemLabel];
      }
      
      isSelected = NO;
   }
   
   return self;
}

//________________________________________________________________________________________
- (void) drawFrame : (CGRect) rect withContext : (CGContextRef) ctx
{
   assert(ctx != nullptr && "drawFrame:withContext, parameter 'ctx' is null");

   CGContextSetAllowsAntialiasing(ctx, false);
   //Bright line at the top.
   CGContextSetRGBStrokeColor(ctx, frameTopLineColor[0], frameTopLineColor[1], frameTopLineColor[2], 1.f);
   CGContextMoveToPoint(ctx, 0.f, 1.f);
   CGContextAddLineToPoint(ctx, rect.size.width, 1.f);
   CGContextStrokePath(ctx);
   
   //Dark line at the bottom.
   CGContextSetRGBStrokeColor(ctx, frameBottomLineColor[0], frameBottomLineColor[1], frameBottomLineColor[2], 1.f);
   CGContextMoveToPoint(ctx, 0.f, rect.size.height);
   CGContextAddLineToPoint(ctx, rect.size.width, rect.size.height);
   CGContextStrokePath(ctx);
   
   CGContextSetAllowsAntialiasing(ctx, true);
}

//________________________________________________________________________________________
- (void) drawRect : (CGRect) rect
{
   CGContextRef ctx = UIGraphicsGetCurrentContext();
   
   //For a separator - simply fill a rectangle with a gradient.
   if (itemStyle == ItemStyle::separator) {
      GradientFillRect(ctx, rect, groupMenuFillColor[0]);
   } else {   
      if (!isSelected) {
         CGContextSetRGBFillColor(ctx, 0.415f, 0.431f, 0.49f, 1.f);//CernAPP::childMenuItemFillColor
         CGContextSetRGBFillColor(ctx, childMenuFillColor[0], childMenuFillColor[1], childMenuFillColor[2], 1.f);
         CGContextFillRect(ctx, rect);
         
         [self drawFrame : rect withContext : ctx];         
      } else {
         const CGFloat colors[][4] = {{0.f, 0.564f, 0.949f, 1.f}, {0.f, 0.431f, .901, 1.f}};
         GradientFillRect(ctx, rect, colors[0]);
      }
   }
}

//________________________________________________________________________________________
- (void) layoutText
{
   if (itemStyle == ItemStyle::separator)
      return;

   CGRect frame = self.frame;
   frame.origin.x = childMenuItemTextIdent;
   frame.origin.y = frame.size.height / 2 - childMenuItemTextHeight / 2;
   frame.size.width -= 2 * childMenuItemTextIdent;
   frame.size.height = childMenuItemTextHeight;

   itemLabel.frame = frame;

}

//________________________________________________________________________________________
- (void) handleTap
{
   [controller itemViewWasSelected : self];
   [menuItem itemPressedIn : controller];
}

@end

@implementation MenuItemsGroupView {
   __weak MenuItemsGroup *groupItem;
   __weak MenuViewController *menuController;
   
   UILabel *itemLabel;
   UIImageView *discloseImageView;
}

//________________________________________________________________________________________
- (id) initWithFrame : (CGRect)frame item : (MenuItemsGroup *) item controller : (MenuViewController *) controller
{
   assert(item != nil && "initWithFrame:item:controller, parameter 'item' is nil");
   assert(controller != nil && "initWithFrame:item:controller, parameter 'controller' is nil");
   
   if (self = [super initWithFrame : frame]) {
      groupItem = item;
      menuController = controller;
      
      UITapGestureRecognizer * const tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget : self action : @selector(handleTap)];
      [tapRecognizer setNumberOfTapsRequired : 1];
      [self addGestureRecognizer : tapRecognizer];
      
      itemLabel = [[UILabel alloc] initWithFrame:CGRect()];
      [self addSubview : itemLabel];
      itemLabel.text = item.itemText;
      UIFont * const font = [UIFont fontWithName : groupMenuFontName size : groupMenuItemFontSize];
      assert(font != nil && "initWithFrame:item:controller:, font not found");
      itemLabel.font = font;
      
      itemLabel.textAlignment = NSTextAlignmentLeft;
      itemLabel.numberOfLines = 1;
      itemLabel.clipsToBounds = YES;
      itemLabel.backgroundColor = [UIColor clearColor];
      itemLabel.textColor = [UIColor colorWithRed : groupTextColor[0] green : groupTextColor[1] blue : groupTextColor[2] alpha : 1.f];

      itemLabel.layer.shadowColor = [UIColor blackColor].CGColor;
      itemLabel.layer.shadowOffset = menuTextShadowOffset;
      itemLabel.layer.shadowOpacity = menuTextShadowAlpha;
      
      discloseImageView = [[UIImageView alloc] initWithImage : [UIImage imageNamed : @"disclose.png"]];
      discloseImageView.clipsToBounds = YES;
      discloseImageView.contentMode = UIViewContentModeScaleAspectFill;
      
      [self addSubview : discloseImageView];
   }
   
   return self;
}

//________________________________________________________________________________________
- (void) drawRect : (CGRect) rect
{
   CGContextRef ctx = UIGraphicsGetCurrentContext();

   GradientFillRect(ctx, rect, groupMenuFillColor[0]);   
   //Dark line at the bottom.
   CGContextSetRGBStrokeColor(ctx, frameBottomLineColor[0], frameBottomLineColor[1], frameBottomLineColor[2], 1.f);
   CGContextMoveToPoint(ctx, 0.f, rect.size.height);
   CGContextAddLineToPoint(ctx, rect.size.width, rect.size.height);
   CGContextStrokePath(ctx);
   
   if (groupItem.itemImage) {
      const CGRect frame = self.frame;//can it be different from the 'rect' parameter???
      const CGRect imageRect = CGRectMake(4.f, frame.size.height / 2 - menuItemImageSize / 2,
                                          menuItemImageSize, menuItemImageSize);
      [groupItem.itemImage drawInRect : imageRect];
   }
}

//________________________________________________________________________________________
- (void) layoutText
{
   CGRect frame = self.frame;
   if (groupItem.itemImage)
      frame.origin.x = menuItemImageSize + 8.f;
   else
      frame.origin.x = groupMenuItemTextIdent;
   
   frame.size.width -= frame.origin.x + groupMenuItemLeftMargin;//Not very smart, but ok.
   frame.origin.y = frame.size.height / 2 - groupMenuItemTextHeight / 2;
   frame.size.height = groupMenuItemTextHeight;

   itemLabel.frame = frame;
   
   discloseImageView.frame = CGRectMake(frame.origin.x + frame.size.width, self.frame.size.height / 2 - discloseTriangleSize / 2, discloseTriangleSize, discloseTriangleSize);
}

//________________________________________________________________________________________
- (MenuItemsGroup *) menuItemsGroup
{
   return groupItem;
}

//________________________________________________________________________________________
- (UIImageView *) discloseImageView
{
   return discloseImageView;
}

//________________________________________________________________________________________
- (void) handleTap
{
   //Collapse or expand.
   [menuController groupViewWasTapped : self];
}

@end