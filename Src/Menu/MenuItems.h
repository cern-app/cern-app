//Author: Timur Pocheptsov.

#import <Foundation/Foundation.h>

#import "ContentProviders.h"

@class MenuViewController;
@class MenuItemsGroupView;
@class MenuItemsGroup;
@class MenuItemView;

//Protocol for menu items (not a class, not to
//have a stupid empty implementation)
@protocol MenuItemProtocol <NSObject>
@required

- (NSString *) itemText;
- (UIImage *) itemImage;

- (void) addMenuItemViewInto : (UIView *) parentView controller : (MenuViewController *) controller;
- (void) deleteItemView;
- (CGFloat) layoutItemViewWithHint : (CGRect) frameHint;
- (CGFloat) requiredHeight;

- (void) setLabelFontSize : (CGFloat) sizeBase;
- (void) setIndent : (CGFloat) indent imageHint : (CGSize) imageHint;

- (NSString *) textForID : (NSUInteger) itemID;

@property (nonatomic) NSUInteger itemID;

@optional
- (void) itemPressedIn : (UIViewController *) controller;

//Since itemView also has a reference to menu item, this reference is weak.
@property (nonatomic) __weak MenuItemsGroup *menuGroup;
@property (nonatomic) __weak MenuItemView *itemView;

@end

//This item corresponds to some content provider,
//when user taps such a item in a menu,
//content provider should load the correct view/controller.
@interface MenuItem : NSObject<MenuItemProtocol>

- (id) initWithContentProvider : (NSObject<ContentProvider> *) provider;

- (NSString *) itemText;
- (UIImage *) itemImage;

- (void) addMenuItemViewInto : (UIView *) parentView controller : (MenuViewController *) controller;
- (void) deleteItemView;
- (CGFloat) layoutItemViewWithHint : (CGRect) frameHint;
- (CGFloat) requiredHeight;

- (void) setLabelFontSize : (CGFloat) sizeBase;
- (void) setIndent : (CGFloat) indent imageHint : (CGSize) imageHint;

- (NSString *) textForID : (NSUInteger) itemID;

- (void) itemPressedIn : (UIViewController *) controller;

@property (nonatomic) NSUInteger itemID;

@property (nonatomic) __weak MenuItemsGroup *menuGroup;
@property (nonatomic) __weak MenuItemView *itemView;

@property (nonatomic) NSObject<ContentProvider> *contentProvider;

@end

//
// Menu group - collapsing/expanding group of items.
//
@interface MenuItemsGroup : NSObject<MenuItemProtocol>

- (id) initWithTitle : (NSString *) title image : (UIImage *) image items : (NSArray *) items;

- (void) addMenuItemViewInto : (UIView *) parentView controller : (MenuViewController *) controller;
- (void) deleteItemView;
- (CGFloat) layoutItemViewWithHint : (CGRect) frameHint;
- (CGFloat) requiredHeight;

- (void) setIndent : (CGFloat) indent imageHint : (CGSize) imageHint;
- (void) setLabelFontSize : (CGFloat) sizeBase;

- (NSString *) itemText;
- (UIImage *) itemImage;

- (NSString *) textForID : (NSUInteger) itemID;
@property (nonatomic) NSUInteger itemID;

@property (nonatomic) BOOL collapsed;
@property (nonatomic) BOOL shrinkable;

- (NSUInteger) nItems;
- (MenuItem *) item : (NSUInteger) item;

@property (nonatomic) __weak MenuItemsGroupView *titleView;
@property (nonatomic) __weak UIView *containerView;
@property (nonatomic) __weak UIView *groupView;

//Menu group can contain expanding sub-groups.
@property (nonatomic) __weak MenuItemsGroup *parentGroup;

@end

//
//Simple non-interactive item without any title or image,
//just to separate different items.
//

@interface MenuSeparator : NSObject<MenuItemProtocol>

- (void) addMenuItemViewInto : (UIView *) parentView controller : (MenuViewController *) controller;
- (CGFloat) layoutItemViewWithHint : (CGRect) frameHint;
- (CGFloat) requiredHeight;

- (void) setIndent : (CGFloat) indent imageHint : (CGSize) imageHint;
- (void) setLabelFontSize : (CGFloat) sizeBase;

- (NSString *) itemText;
- (UIImage *) itemImage;

- (NSString *) textForID : (NSUInteger) itemID;
@property (nonatomic) NSUInteger itemID;

@property (nonatomic) __weak MenuItemView *itemView;

@end
