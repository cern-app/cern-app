//
//  MenuItemViews.h
//  slide_menu
//
//  Created by Timur Pocheptsov on 1/7/13.
//  Copyright (c) 2013 Timur Pocheptsov. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "MenuItems.h"

namespace CernAPP {

enum class ItemStyle {
   standalone,//View for a top-level item.
   child,     //View for a member of a menu-group.
   separator  //View for top-level separator.
};

}

@class MenuViewController;

//View for standalone items (also, child items in a group).
@interface MenuItemView : UIView

- (id) initWithFrame : (CGRect) frame item : (NSObject<MenuItemProtocol> *) item
       style : (CernAPP::ItemStyle) style controller : (MenuViewController *) controller;
- (void) drawRect : (CGRect) rect;

- (void) layoutContent;

- (void) setLabelFontSize : (CGFloat) size;

@property (nonatomic) BOOL isSelected;
@property (nonatomic) CernAPP::ItemStyle itemStyle;

@property (nonatomic) CGFloat indent;
@property (nonatomic) CGSize imageHint;

- (BOOL) isModalViewItem;

@end

//View for a group item (title view).
@interface MenuItemsGroupView : UIView

- (id) initWithFrame : (CGRect) frame item : (MenuItemsGroup *) item
       controller : (MenuViewController *) controller;
- (void) drawRect : (CGRect)rect;

- (void) layoutContent;

- (void) setLabelFontSize : (CGFloat) size;

@property (nonatomic) CGFloat indent;
@property (nonatomic) CGSize imageHint;

- (MenuItemsGroup *) menuItemsGroup;
- (UIImageView *) discloseImageView;

@end



