//
//  MenuItemViews.m
//  slide_menu
//
//  Created by Timur Pocheptsov on 1/7/13.
//  Copyright (c) 2013 Timur Pocheptsov. All rights reserved.
//

#import <utility>
#import <cassert>

#import <QuartzCore/QuartzCore.h>

#import "MenuViewController.h"
#import "MenuItemViews.h"
#import "GUIHelpers.h"

//Menu GUI constants.
//It's a C++, all these constants have
//internal linkage without any 'static',
//and no need for unnamed namespace.
const CGFloat groupMenuLeftMargin = 4.f;
const CGFloat groupMenuItemFontSize = 17.f;
const CGFloat childMenuItemFontSize = 13.f;
const CGSize menuTextShadowOffset = CGSizeMake(2.f, 2.f);
const CGFloat menuTextShadowAlpha = 0.5f;
const CGFloat menuItemImageSize = 24.f;//must be square image.
const CGFloat groupMenuItemTextIndent = 10.f;
const CGFloat discloseTriangleSize = 14.f;
const CGFloat groupMenuItemLeftMargin = 80.f;
const CGFloat childMenuItemImageSize = 15.f;
const CGFloat itemImageMargin = 2.f;

const CGFloat groupMenuFillColor[][4] = {{0.247f, 0.29f, 0.36f, 1.f}, {0.242f, 0.258f, 0.321f, 1.f}};
const CGFloat frameTopLineColor[] = {0.258f, 0.278f, 0.33f};
const CGFloat frameBottomLineColor[] = {0.165f, 0.18f, 0.227f};

const CGFloat groupTextColor[] = {0.615f, 0.635f, 0.69f};

using CernAPP::ItemStyle;

namespace {

//________________________________________________________________________________________
std::pair<CGFloat, CGFloat> TextMetrics(UILabel *label)
{
   assert(label != nil && "TextHeight, parameter 'label' is nil");
   const CGSize lineBounds = [label.text sizeWithFont : label.font];
   return std::make_pair(lineBounds.height - label.font.descender, lineBounds.height);
}

//________________________________________________________________________________________
void DrawFrame(CGContextRef ctx, const CGRect &rect, CGFloat rgbShift)
{
   assert(ctx != nullptr && "DrawFrame, parameter 'ctx' is null");

   CGContextSetAllowsAntialiasing(ctx, false);
   //Bright line at the top.
   CGContextSetRGBStrokeColor(ctx, frameTopLineColor[0] + rgbShift, frameTopLineColor[1] + rgbShift, frameTopLineColor[2] + rgbShift, 1.f);
   CGContextMoveToPoint(ctx, 0.f, 1.f);
   CGContextAddLineToPoint(ctx, rect.size.width, 1.f);
   CGContextStrokePath(ctx);
   
   //Dark line at the bottom.
   CGContextSetRGBStrokeColor(ctx, frameBottomLineColor[0] + rgbShift, frameBottomLineColor[1] + rgbShift, frameBottomLineColor[2] + rgbShift, 1.f);
   CGContextMoveToPoint(ctx, 0.f, rect.size.height);
   CGContextAddLineToPoint(ctx, rect.size.width, rect.size.height);
   CGContextStrokePath(ctx);
   
   CGContextSetAllowsAntialiasing(ctx, true);
}

}

@implementation MenuItemView {
   //Weak, we do not have to control life time of these objects.
   __weak NSObject<MenuItemProtocol> *menuItem;
   __weak MenuViewController *controller;

   UILabel *itemLabel;
   UIImageView *iconView;
}

@synthesize isSelected, itemStyle, indent, imageHint;

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

         UIFont * const font = [UIFont fontWithName : CernAPP::childMenuFontName size : childMenuItemFontSize];
         assert(font != nil && "initWithFrame:item:style:controller:, font not found");
         itemLabel.font = font;
      
         itemLabel.textAlignment = NSTextAlignmentLeft;
         itemLabel.numberOfLines = 1;
         itemLabel.clipsToBounds = YES;
         itemLabel.backgroundColor = [UIColor clearColor];
         
         using CernAPP::childTextColor;
         itemLabel.textColor = [UIColor colorWithRed : childTextColor[0] green : childTextColor[1] blue : childTextColor[2] alpha : 1.f];

         [self addSubview : itemLabel];
         
         iconView = [[UIImageView alloc] initWithFrame : CGRect()];
         
         iconView.image = menuItem.itemImage;
         iconView.contentMode = UIViewContentModeScaleAspectFill;
         iconView.clipsToBounds = YES;
         [self addSubview : iconView];
      }
      
      isSelected = NO;
   }
   
   return self;
}

//________________________________________________________________________________________
- (void) drawRect : (CGRect) rect
{
   CGContextRef ctx = UIGraphicsGetCurrentContext();
   
   //For a separator - simply fill a rectangle with a gradient.
   if (itemStyle == ItemStyle::separator) {
      CernAPP::GradientFillRect(ctx, rect, groupMenuFillColor[0]);
   } else {   
      if (!isSelected) {
         using CernAPP::childMenuFillColor;
         CGContextSetRGBFillColor(ctx, childMenuFillColor[0], childMenuFillColor[1], childMenuFillColor[2], 1.f);
         CGContextFillRect(ctx, rect);
         
         DrawFrame(ctx, rect, 0.f);
      } else
         CernAPP::GradientFillRect(ctx, rect, CernAPP::menuItemHighlightColor[0]);
   }
}

//________________________________________________________________________________________
- (void) layoutContent
{
   if (itemStyle == ItemStyle::separator)
      return;

   using CernAPP::childMenuItemTextIndent;

   CGRect frame = self.frame;
   
   frame.origin.x = indent;
   
   if (imageHint.width > 0.) {
      frame.origin.x += imageHint.width + 2 * itemImageMargin;
   } else {
      frame.origin.x += 2 * itemImageMargin;
   }

   frame.size.width -= frame.origin.x;
   //
   const auto metrics = TextMetrics(itemLabel);
   //
   frame.origin.y = frame.size.height / 2 - metrics.second / 2;
   frame.size.height = metrics.first;

   itemLabel.frame = frame;
   
   //Icon view:
   if (iconView.image) {
      assert(imageHint.width > 0.f && imageHint.height > 0.f && "layoutContent, invalid image hint");
      const CGSize imageSize = iconView.image.size;
      assert(imageSize.width > 0.f && imageSize.height > 0.f &&
             "layoutContent, invalid image size");
      const CGFloat whRatio = imageSize.width / imageSize.height;

      CGRect imageRect = {0.f, self.frame.size.height / 2.f - imageHint.height / 2.f,
                          imageHint.height * whRatio, imageHint.height};
      imageRect.origin.x = indent + (imageHint.width + 2 * itemImageMargin) / 2.f - imageRect.size.width / 2.f;
      iconView.frame = imageRect;
   }
}

//________________________________________________________________________________________
- (void) setLabelFontSize : (CGFloat) size
{
   assert(size > 0.f && "setLabelFontSize:, parameter 'size' must be positive");
   UIFont * const font = [UIFont fontWithName : CernAPP::childMenuFontName size : size];
   assert(font != nil && "initWithFrame:item:style:controller:, font not found");
   itemLabel.font = font;
}

//________________________________________________________________________________________
- (void) handleTap
{
   const BOOL wasSelectedAlready = isSelected;
   [controller itemViewWasSelected : self];
   if (!wasSelectedAlready)
      [menuItem itemPressedIn : controller];
}

@end

@implementation MenuItemsGroupView {
   __weak MenuItemsGroup *groupItem;
   __weak MenuViewController *menuController;
   
   UILabel *itemLabel;
   UIImageView *discloseImageView;
   UIImageView *iconView;
}

@synthesize indent, imageHint;

//________________________________________________________________________________________
- (id) initWithFrame : (CGRect)frame item : (MenuItemsGroup *) item controller : (MenuViewController *) controller
{
   assert(item != nil && "initWithFrame:item:controller:, parameter 'item' is nil");
   assert(controller != nil && "initWithFrame:item:controller:, parameter 'controller' is nil");
   
   if (self = [super initWithFrame : frame]) {
      groupItem = item;
      menuController = controller;
      
      UITapGestureRecognizer * const tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget : self action : @selector(handleTap)];
      [tapRecognizer setNumberOfTapsRequired : 1];
      [self addGestureRecognizer : tapRecognizer];
      
      itemLabel = [[UILabel alloc] initWithFrame:CGRect()];
      [self addSubview : itemLabel];
      itemLabel.text = item.itemText;
      
      UIFont *font = nil;
      if (!groupItem.parentGroup)
         font = [UIFont fontWithName : CernAPP::groupMenuFontName size : groupMenuItemFontSize];
      else
         font = [UIFont fontWithName : CernAPP::childMenuFontName size : childMenuItemFontSize];

      assert(font != nil && "initWithFrame:item:controller:, font not found");
      itemLabel.font = font;

      
      itemLabel.textAlignment = NSTextAlignmentLeft;
      itemLabel.numberOfLines = 1;
      itemLabel.clipsToBounds = YES;
      itemLabel.backgroundColor = [UIColor clearColor];
      
      if (!groupItem.parentGroup)
         itemLabel.textColor = [UIColor colorWithRed : groupTextColor[0] green : groupTextColor[1] blue : groupTextColor[2] alpha : 1.f];
      else {
         using CernAPP::childTextColor;
         itemLabel.textColor = [UIColor colorWithRed : childTextColor[0] green : childTextColor[1] blue : childTextColor[2] alpha : 1.f];
      }
      
      if (groupItem.parentGroup) //Nested group.
         discloseImageView = [[UIImageView alloc] initWithImage : [UIImage imageNamed : @"disclose_child.png"]];
      else {
         //Unfortunately, these nice smooth shadows are very expensive, even
         //if rasterized (we want our interface to rotate and this
         //rotation is jerky because of shadows).
         
         /*
         //Seems to be expensive even on iPad.
         if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            itemLabel.layer.shadowColor = [UIColor blackColor].CGColor;
            itemLabel.layer.shadowOffset = menuTextShadowOffset;
            itemLabel.layer.shadowOpacity = menuTextShadowAlpha;
            
            //Many thanks to tc: http://stackoverflow.com/questions/6395139/i-have-bad-performance-on-using-shadow-effect
            itemLabel.layer.shouldRasterize = YES;
            itemLabel.layer.rasterizationScale = 2.f;
         }
         */

         discloseImageView = [[UIImageView alloc] initWithImage : [UIImage imageNamed : @"disclose.png"]];
      }

      discloseImageView.clipsToBounds = YES;
      discloseImageView.contentMode = UIViewContentModeScaleAspectFill;
      
      [self addSubview : discloseImageView];
      
      iconView = [[UIImageView alloc] initWithFrame : CGRect()];
      iconView.image = groupItem.itemImage;
      iconView.contentMode = UIViewContentModeScaleAspectFill;
      iconView.clipsToBounds = YES;
      [self addSubview : iconView];
   }
   
   return self;
}

//________________________________________________________________________________________
- (void) drawRect : (CGRect) rect
{
   CGContextRef ctx = UIGraphicsGetCurrentContext();

   if (groupItem.parentGroup) {
      //We have a different look & fill for a nested group:
      //it looks like a child menu item, but with a disclose arrow
      //and with a shifted image (if any) and title.
      using CernAPP::childMenuFillColor;
      CGContextSetRGBFillColor(ctx, childMenuFillColor[0], childMenuFillColor[1], childMenuFillColor[2], 1.f);
      CGContextFillRect(ctx, rect);
      DrawFrame(ctx, rect, 0.f);
   } else {
      CernAPP::GradientFillRect(ctx, rect, groupMenuFillColor[0]);
      //Dark line at the bottom.
      CGContextSetRGBStrokeColor(ctx, frameBottomLineColor[0], frameBottomLineColor[1], frameBottomLineColor[2], 1.f);
      CGContextMoveToPoint(ctx, 0.f, rect.size.height);
      CGContextAddLineToPoint(ctx, rect.size.width, rect.size.height);
      CGContextStrokePath(ctx);
   }
}

//________________________________________________________________________________________
- (void) layoutContent
{
   CGRect frame = self.frame;
   
   frame.origin.x = indent;
   
   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
      frame.size.width = CernAPP::menuWidthPad;

   if (imageHint.width) {
      frame.origin.x += 2 * itemImageMargin + imageHint.width;
   } else {//No items at this level have images.
      frame.origin.x += 2 * itemImageMargin;
   }
   
   frame.size.width -= frame.origin.x + groupMenuItemLeftMargin;
   
   const auto metrics = TextMetrics(itemLabel);
   frame.origin.y = frame.size.height / 2.f - metrics.second / 2;
   frame.size.height = metrics.first;

   itemLabel.frame = frame;
   discloseImageView.frame = CGRectMake(frame.origin.x + frame.size.width,
                                        self.frame.size.height / 2 - discloseTriangleSize / 2,
                                        discloseTriangleSize, discloseTriangleSize);
   
   if (iconView.image) {
      assert(imageHint.width > 0.f && imageHint.height &&
             "layoutContent, invalid image size hint");
      const CGSize imageSize = groupItem.itemImage.size;
      assert(imageSize.width > 0.f && imageSize.height > 0.f &&
             "layoutContent, invalid image size");
      const CGFloat whRatio = imageSize.width / imageSize.height;
      
      CGRect imageRect = {0.f, self.frame.size.height / 2.f - imageHint.height / 2.f,
                          imageHint.height * whRatio, imageHint.height};
      imageRect.origin.x = indent + (imageHint.width + 2 * itemImageMargin) / 2.f - imageRect.size.width / 2.f;
      iconView.frame = imageRect;
   }
}

//________________________________________________________________________________________
- (void) setLabelFontSize : (CGFloat) size
{
   assert(size > 0.f && "setLabelFontSize:, parameter 'size' must be positive");
   UIFont * const font = [UIFont fontWithName : groupItem.parentGroup ? CernAPP::childMenuFontName : CernAPP::groupMenuFontName size : size];
   assert(font != nil && "initWithFrame:item:style:controller:, font not found");
   itemLabel.font = font;
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

