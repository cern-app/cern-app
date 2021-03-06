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

#import "NSString+StringSizeWithFont.h"
#import "MenuViewController.h"
#import "MenuItemViews.h"
#import "DeviceCheck.h"
#import "APNHintView.h"
#import "GUIHelpers.h"

const CGFloat groupMenuItemFontSize = 17.f;
const CGFloat childMenuItemFontSize = 13.f;
const CGSize menuTextShadowOffset = CGSizeMake(2.f, 2.f);
const CGFloat discloseTriangleSize = 14.f;
const CGFloat groupMenuItemLeftMargin = 80.f;
const CGFloat itemImageMargin = 2.f;
const CGFloat groupTextColor[] = {0.615f, 0.635f, 0.69f};

using CernAPP::ItemStyle;

namespace {

//________________________________________________________________________________________
std::pair<CGFloat, CGFloat> TextMetrics(UILabel *label)
{
   assert(label != nil && "TextHeight, parameter 'label' is nil");
   const CGSize lineBounds = [label.text sizeWithFont7 : label.font];

   if (CernAPP::SystemVersionGreaterThanOrEqualTo(@"7.0"))
      return std::make_pair(lineBounds.height, lineBounds.height);
   
   return std::make_pair(lineBounds.height - label.font.descender, lineBounds.height);
}

}

@implementation MenuItemView {
   //Weak, we do not have to control life time of these objects.
   __weak MenuViewController *controller;

   UILabel *itemLabel;
   UIImageView *iconView;

   APNHintView *apnView;
}

@synthesize menuItem, isSelected, itemStyle, indent, imageHint;

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

         apnView = [[APNHintView alloc] initWithFrame : CGRect()];
         [self addSubview : apnView];
         apnView.hidden = YES;
      }
      
      isSelected = NO;
   }
   
   return self;
}

//________________________________________________________________________________________
- (void) drawRect : (CGRect) rect
{
   CGContextRef ctx = UIGraphicsGetCurrentContext();
   assert(ctx && "drawRect, invalid graphical context");
   const CGFloat *fillColor = isSelected ? CernAPP::menuItemHighlightColor : CernAPP::menuColor;
   CGContextSetRGBFillColor(ctx, fillColor[0], fillColor[1], fillColor[2], 1.f);
   CGContextFillRect(ctx, rect);
   //Draw a line at the bottom:
   using CernAPP::childTextColor;
   CGContextSetRGBStrokeColor(ctx, childTextColor[0], childTextColor[1], childTextColor[2], 0.1f);
   CGContextSetLineWidth(ctx, 0.5);
   CGContextMoveToPoint(ctx, itemLabel.frame.origin.x * 1.1, rect.size.height - 1);
   CGContextAddLineToPoint(ctx, rect.size.width, rect.size.height - 1);
   CGContextStrokePath(ctx);
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
   
   //Set APN icon frame.
   apnView.frame = CGRectMake(0.f, self.frame.size.height / 2 - 8.f, 16.f, 16.f);
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
- (BOOL) isModalViewItem
{
   if ([menuItem respondsToSelector : @selector(contentProvider)]) {
      NSObject<ContentProvider> * const provider = [menuItem performSelector : @selector(contentProvider)];
      return [provider isKindOfClass : [ModalViewProvider class]];
   }

   return NO;
}

//________________________________________________________________________________________
- (void) handleTap
{
   if ([controller itemViewWasSelected : self])
      [menuItem itemPressedIn : controller];
}

#pragma mark - APN hints.

//________________________________________________________________________________________
- (void) setApnItems : (NSUInteger) nItems
{
   if (nItems) {
      const NSUInteger prevNumber = apnView.count;
      if (!prevNumber) {
         iconView.hidden = YES;
         apnView.hidden = NO;
      }
      
      apnView.count = nItems;

      if (!prevNumber)
         [self setNeedsDisplay];
   } else {
      apnView.count = 0;
      apnView.hidden = YES;
      iconView.hidden = NO;
      
      [self setNeedsDisplay];
   }
}

//________________________________________________________________________________________
- (NSUInteger) apnItems
{
   return apnView.count;
}

@end

@implementation MenuItemsGroupView {
   __weak MenuItemsGroup *groupItem;
   __weak MenuViewController *menuController;
   
   UILabel *itemLabel;
   UIImageView *discloseImageView;
   UIImageView *iconView;

   APNHintView *apnView;
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
      else
         discloseImageView = [[UIImageView alloc] initWithImage : [UIImage imageNamed : @"disclose.png"]];

      discloseImageView.clipsToBounds = YES;
      discloseImageView.contentMode = UIViewContentModeScaleAspectFill;
      
      [self addSubview : discloseImageView];
      
      iconView = [[UIImageView alloc] initWithFrame : CGRect()];
      iconView.image = groupItem.itemImage;
      iconView.contentMode = UIViewContentModeScaleAspectFill;
      iconView.clipsToBounds = YES;
      [self addSubview : iconView];
    
      apnView = [[APNHintView alloc] initWithFrame : CGRect()];
      [self addSubview : apnView];
      apnView.hidden = YES;
   }
   
   return self;
}

//________________________________________________________________________________________
- (void) drawRect : (CGRect) rect
{
   using CernAPP::menuColor;
   CGContextRef ctx = UIGraphicsGetCurrentContext();
   assert(ctx && "drawRect, invalid graphical context");
   CGContextSetRGBFillColor(ctx, menuColor[0], menuColor[1], menuColor[2], 1.f);
   CGContextFillRect(ctx, rect);
   //Draw a line at the bottom:
   using CernAPP::childTextColor;
   CGContextSetRGBStrokeColor(ctx, childTextColor[0], childTextColor[1], childTextColor[2], 0.1f);
   CGContextSetLineWidth(ctx, 0.5);
   CGContextMoveToPoint(ctx, itemLabel.frame.origin.x * 1.1, rect.size.height - 1);
   CGContextAddLineToPoint(ctx, rect.size.width, rect.size.height - 1);
   CGContextStrokePath(ctx);
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
   
   //Set APN icon frame.
   apnView.frame = CGRectMake(0.f, self.frame.size.height / 2 - 9.f, 18.f, 18.f);
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

#pragma mark - APN hints.

//________________________________________________________________________________________
- (void) setApnItems : (NSUInteger) nItems
{
   if (nItems) {
      if (!apnView.count) {
         apnView.hidden = NO;
         iconView.hidden = YES;
      }
      
      apnView.count = nItems;
   } else {
      apnView.count = nItems;
      apnView.hidden = YES;
      iconView.hidden = NO;
   }
}

//________________________________________________________________________________________
- (NSUInteger) apnItems
{
   return apnView.count;
}

@end

