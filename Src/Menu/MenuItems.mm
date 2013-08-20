//Author: Timur Pocheptsov.

#import <cassert>

#import "StaticInfoScrollViewController.h"
#import "MenuNavigationController.h"
#import "ECSlidingViewController.h"
#import "StoryboardIdentifiers.h"
#import "MenuViewController.h"
#import "MenuItemViews.h"
#import "GUIHelpers.h"
#import "MenuItems.h"

using CernAPP::ItemStyle;

namespace {

//________________________________________________________________________________________
CGFloat DefaultGUIFontSize()
{
   //The "GUI font size" is the text size in a menu.
   //On iPhone it is in the range [13, 17] (this version was developed first),
   //on iPad fonts are bigger.

   const CGFloat add = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? 1.5f : 0.f;

   NSUserDefaults * const defaults = [NSUserDefaults standardUserDefaults];
   if (id sz = [defaults objectForKey:@"GUIFontSize"]) {
      assert([sz isKindOfClass : [NSNumber class]] && "DefaultGUIFontSize, 'GUIFontSize' has a wrong type");
      return [(NSNumber *)sz floatValue] + add;
   }
   
   //Ooops.
   return 13.f + add;
}

}

//Single menu item, can be standalone or a group member.
@implementation MenuItem {
   NSString *itemTitle;
}

@synthesize itemView, menuGroup, contentProvider, itemID;

//________________________________________________________________________________________
- (id) initWithContentProvider : (NSObject<ContentProvider> *) provider
{
   assert(provider != nil && "initWithTitle:contentProvider:, parameter 'provider' is nil");
   
   if (self = [super init]) {
      itemTitle = provider.categoryName;
      contentProvider = provider;
      
      if ([contentProvider respondsToSelector : @selector(providerID)])
         itemID = contentProvider.providerID;
      else
         itemID = 0;
   }

   return self;
}

//________________________________________________________________________________________
- (NSString *) itemText
{
   return itemTitle;
}

//________________________________________________________________________________________
- (UIImage *) itemImage
{
   //No images at the moment.
   return contentProvider.categoryImage;
}

//________________________________________________________________________________________
- (void) addMenuItemViewInto : (UIView *) parentView controller : (MenuViewController *) controller
{
   assert(parentView != nil && "addMenuItemViewInto:controller:, parameter 'parentView' is nil");
   assert(controller != nil && "addMenuItemViewInto:controller:, parameter 'controller' is nil");
   //
   MenuItemView * const newView = [[MenuItemView alloc] initWithFrame : CGRect() item : self
                                   style : ItemStyle::child controller : controller];
     
   itemView = newView;
   [itemView setLabelFontSize : DefaultGUIFontSize()];
   [parentView addSubview : newView];
}

//________________________________________________________________________________________
- (void) deleteItemView
{
   if (itemView)
      [itemView removeFromSuperview];
}

//________________________________________________________________________________________
- (CGFloat) layoutItemViewWithHint : (CGRect) hint
{
   assert(itemView != nil && "layoutItemViewWithHint:, itemView is nil");

   hint.size.height = CernAPP::ChildMenuItemHeight();
   itemView.frame = hint;   
   [itemView layoutContent];

   return CernAPP::ChildMenuItemHeight();
}

//________________________________________________________________________________________
- (CGFloat) requiredHeight
{
   return CernAPP::ChildMenuItemHeight();
}

//________________________________________________________________________________________
- (void) setIndent : (CGFloat) indent imageHint : (CGSize) imageHint
{
   assert(indent >= 0.f && "setIndent:imageHint:, parameter 'indent' is negative");
   assert(itemView != nil && "setIndent:imageHint:, itemView is nil");

   itemView.indent = indent;
   itemView.imageHint = imageHint;
}

//________________________________________________________________________________________
- (void) setLabelFontSize : (CGFloat) size
{
   assert(size > 0 && "setLabelFontSize:, parameter 'size' must be positive");
   assert(itemView != nil && "setLabelFontSize:, itemView is nil");
   [itemView setLabelFontSize : size];
}

//________________________________________________________________________________________
- (NSString *) textForID : (NSUInteger) anItemID
{
   if (itemID == anItemID)
      return self.itemText;
   
   return nil;
}

//________________________________________________________________________________________
- (void) itemPressedIn : (UIViewController *) controller
{
   assert(controller != nil && "itemPressedIn:, parameter 'controller' is nil");
   //Ask content provider to load correct view/controller.
   [contentProvider loadControllerTo : controller];
}

@end

//
//A group of items, can be collapsed/expanded,
//can be at the top level of a menu or a
//nested sub-group in another group.
//

@implementation MenuItemsGroup {
   NSArray *items;
   NSString *title;
   UIImage *image;
}

@synthesize collapsed, shrinkable, titleView, containerView, groupView, parentGroup, itemID;

//________________________________________________________________________________________
- (id) initWithTitle : (NSString *) aTitle image : (UIImage *) anImage items : (NSArray *) anItems
{
   assert(aTitle != nil && "initWithTitle:image:items:, parameter 'aTitle' is nil");
   //image can be nil.
   assert(anItems != nil && "initWithTitle:image:items:, parameter 'anItems' is nil");
   assert(anItems.count != 0 && "initWithTitle:image:items:, number of items must be > 0");
   
   if (self = [super init]) {
      title = aTitle;
      image = anImage;
      items = anItems;
      collapsed = NO;//Opened by default.      
      shrinkable = YES;
      parentGroup = nil;
   }

   return self;
}

//________________________________________________________________________________________
- (void) addMenuItemViewInto : (UIView *) parentView controller : (MenuViewController *) controller
{
   assert(parentView != nil && "addMenuItemViewInto:controller:, parameter 'parentView' is nil");
   assert(controller != nil && "addMenuItemViewInto:controller:, parameter 'controller' is nil");
   
   UIView * const newContainerView = [[UIView alloc] initWithFrame : CGRect()];
   newContainerView.clipsToBounds = YES;
   UIView * const newGroupView = [[UIView alloc] initWithFrame : CGRect()];
   [newContainerView addSubview : newGroupView];
   [parentView addSubview : newContainerView];
         
   for (NSObject<MenuItemProtocol> *item in items) {
      assert([item respondsToSelector:@selector(addMenuItemViewInto:controller:)] &&
             "addMenuItemViewInto:controller:, child item must reposng to 'addMenuItemViewInto:controller: method'");

      [item addMenuItemViewInto : newGroupView controller : controller];
      
      if ([item respondsToSelector:@selector(menuGroup)])
         item.menuGroup = self;
   }

   MenuItemsGroupView * const menuGroupView = [[MenuItemsGroupView alloc] initWithFrame : CGRect()
                                               item : self controller : controller];
   [parentView addSubview : menuGroupView];
         
   titleView = menuGroupView;
   if (!parentGroup)
      [titleView setLabelFontSize : DefaultGUIFontSize() + 4.f];
   else
      [titleView setLabelFontSize : DefaultGUIFontSize()];

   containerView = newContainerView;
   groupView = newGroupView;
}

//________________________________________________________________________________________
- (void) deleteItemView
{
   if (titleView)
      [titleView removeFromSuperview];
   if (containerView)
      [containerView removeFromSuperview];//Group view and item views are children of this, nobody else reference them.
}


//________________________________________________________________________________________
- (CGFloat) layoutItemViewWithHint : (CGRect) hint
{
   assert(titleView != nil && "layoutItemViewWithHint:, titleView is nil");
   assert(containerView != nil && "layoutItemViewWithHint:, containerView is nil");
   assert(groupView != nil && "layouItemViewWithHint:, containerView is nil");
   
   CGFloat totalHeight = 0.f;
   
   if (!parentGroup)
      hint.size.height = CernAPP::GroupMenuItemHeight();
   else
      hint.size.height = CernAPP::ChildMenuItemHeight();
   
   titleView.frame = hint;
   [titleView layoutContent];
   
   totalHeight += hint.size.height;
   hint.origin.y += hint.size.height;

   hint.size.height = [self requiredHeight];
   if (!parentGroup)
      hint.size.height -= CernAPP::GroupMenuItemHeight();
   else
      hint.size.height -= CernAPP::ChildMenuItemHeight();

   containerView.frame = hint;

   if (!collapsed) {
      hint.origin = CGPoint();
      titleView.discloseImageView.transform = CGAffineTransformMakeRotation(0.f);
   } else {
      hint.origin.y = -hint.size.height;
      groupView.alpha = 0.f;//well, this is not a layout actually, but ok.
   }

   groupView.frame = hint;
   
   //Layout sub-views.
   hint.origin = CGPoint();
   
   for (NSObject<MenuItemProtocol> *menuItem in items)
      hint.origin.y += [menuItem layoutItemViewWithHint : hint];
   
   totalHeight += hint.size.height;

   if (collapsed) {
      if (parentGroup)
         return CernAPP::ChildMenuItemHeight();
      else
         return CernAPP::GroupMenuItemHeight();
   }

   return totalHeight;
}

//________________________________________________________________________________________
- (CGFloat) requiredHeight
{
   //The height required by this menu as it's in open state now.
   CGFloat totalHeight = 0.f;

   if (!parentGroup)
      totalHeight = CernAPP::GroupMenuItemHeight();
   else
      totalHeight = CernAPP::ChildMenuItemHeight();
   
   //If it's open, also calculate the height of sub-items.
   for (NSObject<MenuItemProtocol> *menuItem in items) {
      if ([menuItem isKindOfClass : [MenuItemsGroup class]]) {
         //For the nested sub-group, we calculate its total height only if its open.
         MenuItemsGroup * const subGroup = (MenuItemsGroup *)menuItem;
         if (!subGroup.collapsed)
            totalHeight += [menuItem requiredHeight];
         else
            totalHeight += CernAPP::ChildMenuItemHeight();
      } else
         totalHeight += [menuItem requiredHeight];
   }
   
   return totalHeight;
}

//________________________________________________________________________________________
- (void) setIndent : (CGFloat) indent imageHint : (CGSize) imageHint
{
   assert(indent >= 0.f && "setIndent:imageHint:, parameter 'indent' is negative");
   assert(titleView != nil && "setIndent:imageHint:, titleView is nil");
   
   titleView.indent = indent;
   titleView.imageHint = imageHint;
   
   CGFloat whRatio = 0.f;
   for (NSObject<MenuItemProtocol> *menuItem in items) {
      if (UIImage * const childImage = menuItem.itemImage) {
         const CGSize sz = childImage.size;
         assert(sz.width > 0.f && sz.height > 0.f &&
                "setIndent:imageHeight, child item has an invalid image size");
         if (sz.width / sz.height > whRatio)
            whRatio = sz.width / sz.height;
      }
   }
   
   CGSize childImageHint = {};
   if (whRatio) {
      childImageHint.width = CernAPP::childMenuItemImageHeight * whRatio;
      childImageHint.height = CernAPP::childMenuItemImageHeight;
   }

   indent += CernAPP::childMenuItemTextIndent;

   for (NSObject<MenuItemProtocol> *menuItem in items)
      [menuItem setIndent : indent imageHint : childImageHint];
}

//________________________________________________________________________________________
- (void) setLabelFontSize : (CGFloat) sizeBase
{
   assert(sizeBase > 0 && "setLabelFontSize:, parameter 'sizeBase' must be positive");
   assert(titleView != nil && "setLabelFontSize:, titleView is nil");
   
   if (!parentGroup)
      [titleView setLabelFontSize : sizeBase + 4];
   else
      [titleView setLabelFontSize : sizeBase];
   
   for (NSObject<MenuItemProtocol> *menuItem in items)
      [menuItem setLabelFontSize : sizeBase];
}

//________________________________________________________________________________________
- (NSString *) textForID : (NSUInteger) anItemID
{
   if (itemID == anItemID)
      return self.itemText;
   
   for (NSObject<MenuItemProtocol> *item in items) {
      if (NSString *text = [item textForID : anItemID])
         return text;
   }

   return nil;
}

//________________________________________________________________________________________
- (NSString *) itemText
{
   return title;
}

//________________________________________________________________________________________
- (UIImage *) itemImage
{
   return image;
}

//________________________________________________________________________________________
- (NSUInteger) nItems
{
   return items.count;
}

//________________________________________________________________________________________
- (MenuItem *) item : (NSUInteger) item;
{
   assert(item < items.count && "viewForItem:, parameter 'item' is out of bounds");
   return items[item];
}

@end

//
//Item separator.
//

@implementation MenuSeparator

@synthesize itemView, itemID;

//________________________________________________________________________________________
- (void) addMenuItemViewInto : (UIView *) parentView controller : (MenuViewController *) controller
{
   assert(parentView != nil && "addMenuItemViewInto:controller:, parameter 'parentView' is nil");
   assert(parentView != nil && "addMenuItemViewInto:controller:, parameter 'controller' is nil");
   
   MenuItemView * const separatorView = [[MenuItemView alloc] initWithFrame : CGRect() item : nil style : ItemStyle::separator controller : controller];
   itemView = separatorView;
   [parentView addSubview : separatorView];
}

//________________________________________________________________________________________
- (void) deleteItemView
{
   if (itemView)
      [itemView removeFromSuperview];
}

//________________________________________________________________________________________
- (CGFloat) layoutItemViewWithHint : (CGRect) frameHint
{
   assert(itemView != nil && "layoutItemViewWithHint:, itemView is nil");

   frameHint.size.height = CernAPP::SeparatorItemHeight();
   itemView.frame = frameHint;

   return CernAPP::SeparatorItemHeight();
}

//________________________________________________________________________________________
- (CGFloat) requiredHeight
{
   return CernAPP::SeparatorItemHeight();
}

//________________________________________________________________________________________
- (void) setIndent : (CGFloat) indent imageHint : (CGSize) imageHint
{
#pragma unused(indent, imageHint)
   //NOOP.
}

//________________________________________________________________________________________
- (void) setLabelFontSize : (CGFloat) sizeBase
{
#pragma unused(sizeBase)
   //NOOP.
}

//________________________________________________________________________________________
- (NSString *) textForID : (NSUInteger) itemID
{
#pragma unused(itemID)
   //NOOP.
   return nil;
}

//________________________________________________________________________________________
- (NSString *) itemText
{
   //NOOP.
   return nil;
}

//________________________________________________________________________________________
- (UIImage *) itemImage
{
   //NOOP.
   return nil;
}

@end
