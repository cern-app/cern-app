#import <cassert>
#import <cmath>

#import "ECSlidingViewController.h"
#import "StoryboardIdentifiers.h"
#import "MenuViewController.h"
#import "ContentProviders.h"
#import "MenuItemViews.h"
#import "Experiments.h"
#import "GUIHelpers.h"
#import "MenuItems.h"

using CernAPP::ItemStyle;

namespace {

enum class MenuUpdateStage {
   none,
   menuPlistUpdate,
   livePlistUpdate
};

//________________________________________________________________________________________
NSDictionary *LoadOfflineMenuPlist(NSString * plistName)
{
   assert(plistName != nil && "LoadOfflineMenuPlist, parameter 'plistName' is nil");

   NSDictionary *plist = nil;
   NSArray * const paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
   for (NSString *dir in paths) {
      NSString * const plistPath = [dir stringByAppendingPathComponent : [plistName stringByAppendingString : @".plist"]];
      if ([[NSFileManager defaultManager] fileExistsAtPath : plistPath]) {
         //Ok, create a dictionary from the 'MENU.plist'.
         plist = [NSDictionary dictionaryWithContentsOfFile : plistPath];
      }
   }

   if (!plist) {
      NSString * const path = [[NSBundle mainBundle] pathForResource : plistName ofType : @"plist"];
      plist = [NSDictionary dictionaryWithContentsOfFile : path];
      assert(plist != nil && "loadOfflineMenuPlists, no dictionary or 'FILENAME.plist' found");
   }
   
   return plist;
}

//________________________________________________________________________________________
void WriteOfflineMenuPlist(NSDictionary *plist, NSString *plistName)
{
   assert(plist != nil && "WriteOfflineMenuPlist, parameter 'plist' is nil");
   assert(plistName != nil && "WriteOfflineMenuPlist, parameter 'plistName' is nil");
   
   NSArray * const paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
   if (paths.count) {
      NSString * const dir = (NSString *)paths[0];
      NSString * const filePath = [dir stringByAppendingPathComponent : plistName];
      [plist writeToFile : filePath atomically : YES];
   }
}

}

@implementation MenuViewController {
   NSMutableArray *menuItems;
   MenuItemView *selectedItemView;
   
   BOOL inAnimation;
   __weak MenuItemsGroup *newOpen;
   
   NSMutableArray *liveData;
   
   NSURLConnection *connection;
   NSMutableData *menuData;
   
   NSDictionary *menuPlist;
   NSDictionary *livePlist;
   
   MenuUpdateStage updateStage;
}

//________________________________________________________________________________________
- (UIImage *) loadItemImage : (NSDictionary *) desc
{
   assert(desc != nil && "loadItemImage:, parameter 'desc' is nil");
   
   if (id objBase = desc[@"Image name"]) {
      assert([objBase isKindOfClass : [NSString class]] &&
             "loadItemImage:, 'Image name' must be a NSString");
      
      return [UIImage imageNamed : (NSString *)objBase];
   }
   
   return nil;
}

//________________________________________________________________________________________
- (void) setStateForGroup : (NSUInteger) groupIndex from : (NSDictionary *) desc
{
   assert(groupIndex < menuItems.count && "setStateForGroup:from:, parameter 'groupIndex' is out of bounds");
   assert([menuItems[groupIndex] isKindOfClass : [MenuItemsGroup class]] &&
          "setStateForGroup:from:, state can be set only for a sub-menu");
   assert(desc != nil && "setStateForGroup:from:, parameter 'desc' is nil");

   MenuItemsGroup * const group = (MenuItemsGroup *)menuItems[groupIndex];
   
   assert([desc[@"Expanded"] isKindOfClass : [NSNumber class]] &&
          "setStateForGroup:from:, 'Expanded' is not found or has a wrong type");
   
   const NSInteger val = [(NSNumber *)desc[@"Expanded"] integerValue];
   assert(val >= 0 && val <= 2 && "setStateForGroup:from:, 'Expanded' can have a vlue only 0, 1 or 2");

   if (!val) {
      group.collapsed = YES;
      group.containerView.hidden = YES;
      group.titleView.discloseImageView.transform = CGAffineTransformMakeRotation(-M_PI / 2);
   } else if (val == 1 || val == 2) {
      group.collapsed = NO;
      if (val == 2) {
         group.shrinkable = NO;
         group.titleView.discloseImageView.image = [UIImage imageNamed : @"disclose_disabled.png"];
      }
   }
}

//________________________________________________________________________________________
- (void) addMenuGroup : (NSString *) groupName withImage : (UIImage *) groupImage forItems : (NSMutableArray *) items
{
   assert(groupName != nil && "addMenuGroup:withImage:forItems:, parameter 'groupName' is nil");
   //groupImage can be nil, it's ok.
   assert(items != nil && "addMenuGroup:withImage:forItems:, parameter 'items' is nil");

   MenuItemsGroup * const group = [[MenuItemsGroup alloc] initWithTitle : groupName image : groupImage items : items];
   
   for (NSObject<MenuItemProtocol> *menuItem in items) {
      if ([menuItem isKindOfClass : [MenuItemsGroup class]]) {
         MenuItemsGroup *const nestedGroup = (MenuItemsGroup *)menuItem;
         nestedGroup.parentGroup = group;
         nestedGroup.collapsed = YES;//By default, nested sub-menu is closed.
      }
   }
   
   [group addMenuItemViewInto : scrollView controller : self];
   [menuItems addObject : group];
   
   for (NSObject<MenuItemProtocol> *menuItem in items) {
      if ([menuItem isKindOfClass : [MenuItemsGroup class]]) {
         MenuItemsGroup *const nestedGroup = (MenuItemsGroup *)menuItem;
         MenuItemsGroupView * const view = nestedGroup.titleView;
         nestedGroup.containerView.hidden = YES;
         view.discloseImageView.transform = CGAffineTransformMakeRotation(-M_PI / 2);
      }
   }
}

#pragma mark - Different menu item "loaders" - read the description from plist and fill the menu.

//1. These are simple "single-item loaders".

//________________________________________________________________________________________
- (BOOL) loadFeed : (NSDictionary *) desc into : (NSMutableArray *) items
{
   //This can be both the top-level and a nested item.

   assert(desc != nil && "loadFeed:into:, parameter 'desc' is nil");
   assert(items != nil && "loadFeed:into:, parameter 'items' is nil");
   
   assert([desc[@"Category name"] isKindOfClass : [NSString class]] &&
          "loadFeed:into:, 'Category name' not found or has a wrong type");
   
   NSString * const categoryName = (NSString *)desc[@"Category name"];
   if (![categoryName isEqualToString : @"Feed"] && ![categoryName isEqualToString : @"Tweet"])
      return NO;

   FeedProvider * const provider = [[FeedProvider alloc] initWith : desc];
   MenuItem * const newItem = [[MenuItem alloc] initWithContentProvider : provider];
   [items addObject : newItem];
   
   return YES;
}

//________________________________________________________________________________________
- (BOOL) loadBulletin : (NSDictionary *) desc into : (NSMutableArray *) items
{
   //Both the top-level and nested item.

   assert(desc != nil && "loadBulletin:into:, parameter 'desc' is nil");
   assert(items != nil && "loadBulletin:into:, parameter 'items' is nil");
   assert([desc[@"Category name"] isKindOfClass : [NSString class]] &&
          "loadBulletin:into:, 'Category name' not found or has a wrong type");
   
   if (![(NSString *)desc[@"Category name"] isEqualToString : @"Bulletin"])
      return NO;

   BulletinProvider * const provider = [[BulletinProvider alloc] initWithDictionary : desc];
   MenuItem * const menuItem = [[MenuItem alloc] initWithContentProvider : provider];
   [items addObject : menuItem];
   
   return YES;
}

//________________________________________________________________________________________
- (BOOL) loadPhotoSet : (NSDictionary *) desc into : (NSMutableArray *) items
{
   //Both a top-level and a nested item.
   
   //This is an 'ad-hoc' provider (it does a lot of special work to find
   //images in our quite  special sources).

   assert(desc != nil && "loadPhotoSet:into:, parameter 'desc' is nil");
   assert(items != nil && "loadPhotoSet:into:, parameter 'items' is nil");
   assert([desc[@"Category name"] isKindOfClass : [NSString class]] &&
          "loadPhotoSet:into:, 'Category name' is nil or has a wrong type");
   
   if (![(NSString *)desc[@"Category name"] isEqualToString : @"PhotoSet"])
      return NO;

   PhotoSetProvider * const provider = [[PhotoSetProvider alloc] initWithDictionary : desc];
   MenuItem * const menuItem = [[MenuItem alloc] initWithContentProvider : provider];
   [items addObject : menuItem];

   return YES;
}

//________________________________________________________________________________________
- (BOOL) loadVideoSet : (NSDictionary *) desc into : (NSMutableArray *) items
{
   //Both the top-level and nested item.
   
   //This is an 'ad-hoc' content provider (it does a lot of special worn
   //to extract video from our quite special source).
   //That's why the provider is 'LatestVideosProvider'.

   assert(desc != nil && "loadVideoSet:into:, parameter 'desc' is nil");
   assert(items != nil && "loadVideoSet:into:, parameter 'items' is nil");
   assert([desc[@"Category name"] isKindOfClass : [NSString class]] &&
          "loadVideoSet:into:, 'Category name' not found or has a wrong type");
   
   if (![(NSString *)desc[@"Category name"] isEqualToString : @"VideoSet"])
      return NO;
   
   LatestVideosProvider * const provider = [[LatestVideosProvider alloc] initWithDictionary : desc];
   MenuItem * const menuItem = [[MenuItem alloc] initWithContentProvider : provider];
   [items addObject : menuItem];

   return YES;
}

//________________________________________________________________________________________
- (BOOL) loadSpecialItem : (NSDictionary *) desc into : (NSMutableArray *) items
{
   assert(desc != nil && "loadSpecialItem:into:, parameter 'desc' is nil");
   assert(items != nil && "loadSpecialItem:into:, parameter 'items' is nil");
   
   assert([desc[@"Category name"] isKindOfClass : [NSString class]] &&
          "loadStandaloneItem:, 'Category name' not found or has a wrong type");
   
   NSString * const catName = (NSString *)desc[@"Category name"];
   
   if ([catName isEqualToString : @"ModalViewItem"] || [catName isEqualToString : @"NavigationViewItem"]) {
      NSObject<ContentProvider> *provider = nil;
      
      if ([catName isEqualToString : @"ModalViewItem"])
         provider = [[ModalViewProvider alloc] initWithDictionary : desc];
      else
         provider = [[NavigationViewProvider alloc] initWithDictionary : desc];
      
      MenuItem * const menuItem = [[MenuItem alloc] initWithContentProvider : provider];
      [items addObject : menuItem];
      [menuItem addMenuItemViewInto : scrollView controller : self];
      if (items == menuItems)//it's a top-level item ('standalone').
         menuItem.itemView.itemStyle = CernAPP::ItemStyle::standalone;

      return YES;
   } //Something else special.
   
   return NO;
}

//________________________________________________________________________________________
- (BOOL) loadSeparator : (NSDictionary *) desc
{
   //Can be top-level only.

   assert(desc != nil && "loadSeparator:, parameter 'desc' is nil");
   
   id objBase = desc[@"Category name"];
   assert(objBase != nil && [objBase isKindOfClass : [NSString class]] &&
          "loadSeparator:, 'Category name' either not found or has a wrong type");
   
   if ([(NSString *)objBase isEqualToString : @"Separator"]) {
      MenuSeparator * const separator = [[MenuSeparator alloc] init];
      [separator addMenuItemViewInto : scrollView controller : self];
      [menuItems addObject : separator];
      return YES;
   }
   
   return NO;
}

//________________________________________________________________________________________
- (BOOL) loadSpecialItem : (NSDictionary *) desc
{
   return [self loadSpecialItem : desc into : menuItems];
}

//These are more complex "loaders".

//________________________________________________________________________________________
- (BOOL) loadMenuGroup : (NSDictionary *) desc
{
   //This is a "TOP-level" menu group.
   //This menu group can contain only simple, non-group items.
   
   assert(scrollView != nil && "loadMenuGroup:, scrollView is not loaded yet!");
   assert(desc != nil && "loadMenuGroup:, parameter 'desc' is nil");
   assert([desc[@"Category name"] isKindOfClass : [NSString class]] &&
          "loadMenuGroup:, 'Category Name' not found or has a wrong type");
   
   if (![(NSString *)desc[@"Category name"] isEqualToString : @"Menu group"])
      return NO;
   
   //Find a section name, it's a required property.
   assert([desc[@"Name"] isKindOfClass : [NSString class]] &&
          "loadMenuGroup:, 'Name' is not found, or has a wrong type");
   
   NSString * const sectionName = (NSString *)desc[@"Name"];
   //Now, we need an array of either feeds or tweets.
   if (desc[@"Items"]) {
      assert([desc[@"Items"] isKindOfClass : [NSArray class]] &&
             "loadNewsSection:, 'Items' must have a NSArray type");
      NSArray * const plistItems = (NSArray *)desc[@"Items"];
      if (plistItems.count) {
         //Read news feeds.
         NSMutableArray * const groupItems = [[NSMutableArray alloc] init];
         for (id info in plistItems) {
            assert([info isKindOfClass : [NSDictionary class]] &&
                   "loadNewsSection, item info must be a dictionary");
            
            NSDictionary * const itemInfo = (NSDictionary *)info;
            //Now, we try to initialize correct content provider,
            //using item's 'Category name':
            if ([self loadFeed : itemInfo into : groupItems])
               continue;
            
            if ([self loadBulletin : itemInfo into : groupItems])
               continue;
            
            if ([self loadPhotoSet : itemInfo into : groupItems])
               continue;
            
            if ([self loadVideoSet : itemInfo into : groupItems])
               continue;
            
            if ([self loadSpecialItem : itemInfo into : groupItems])
               continue;
         }
         
         [self addMenuGroup : sectionName withImage : [self loadItemImage : desc] forItems : groupItems];
         [self setStateForGroup : menuItems.count - 1 from : desc];
      }
   }

   return YES;
}


//________________________________________________________________________________________
- (BOOL) loadLIVESection : (NSDictionary *) desc
{
   //This is 'ad-hoc' solution, it's based on an old CERNLive.plist from app. v.1
   //and the code to read this plist and create content providers.
   
   //LIVE is a top-level menu-group with (probably) nested menu-groups.

   assert(desc != nil && "loadLIVESection:, parameter 'desc' is nil");
   
   id objBase = desc[@"Category name"];
   assert(objBase != nil && "loadLIVESection:, 'Category Name' not found");
   assert([objBase isKindOfClass : [NSString class]] &&
          "loadLIVESection:, 'Category Name' must have a NSString type");
   
   NSString * const catName = (NSString *)objBase;
   if (![catName isEqualToString : @"LIVE"])
      return NO;

   [self readLIVEData : desc];

   return YES;
}

//________________________________________________________________________________________
- (BOOL) loadStaticInfo : (NSDictionary *) desc
{
   //This is another 'ad-hoc' menu-group, base on StaticInformation.plist from
   //v.1 of our app. This menu-group can have nested sub-groups.

   assert(desc != nil && "loadStaticInfo, parameter 'desc' is nil");

   id objBase = desc[@"Category name"];
   assert([objBase isKindOfClass : [NSString class]] &&
          "loadStaticInfo:, 'Category name' either not found or has a wrong type");
   
   if (![(NSString *)objBase isEqualToString : @"StaticInfo"])
      return NO;

   NSString * const path = [[NSBundle mainBundle] pathForResource : @"StaticInformation" ofType : @"plist"];
   NSDictionary * const plistDict = [NSDictionary dictionaryWithContentsOfFile : path];
   assert(plistDict != nil && "loadStaticInfo:, no dictionary or StaticInformation.plist found");

   objBase = plistDict[@"Root"];
   assert([objBase isKindOfClass : [NSArray class]] && "loadStaticInfo:, 'Root' not found or has a wrong type");
   //We have an array of dictionaries.
   NSArray * const entries = (NSArray *)objBase;
   
   if (entries.count) {
      //Items for a new group.
      NSMutableArray * const items = [[NSMutableArray alloc] init];
      for (objBase in entries) {
         assert([objBase isKindOfClass : [NSDictionary class]] &&
                "loadStaticInfo:, array of dictionaries expected");
         NSDictionary * const itemDict = (NSDictionary *)objBase;
         assert([itemDict[@"Items"] isKindOfClass : [NSArray class]] &&
                "loadStaticInfo:, 'Items' is either nil or has a wrong type");
         NSArray * const staticInfo = (NSArray *)itemDict[@"Items"];
         //Again, this must be an array of dictionaries.
         assert([staticInfo[0] isKindOfClass : [NSDictionary class]] &&
                "loadStaticInfo:, 'Items' must be an array of dictionaries");
         
         //Now we check, what do we have inside.
         NSDictionary * const firstItem = (NSDictionary *)staticInfo[0];
         if (firstItem[@"Items"]) {
            NSMutableArray * const subMenu = [[NSMutableArray alloc] init];
            for (id dictBase in staticInfo) {
               assert([dictBase isKindOfClass : [NSDictionary class]] &&
                      "loadStaticInfo:, array of dictionaries expected");
               StaticInfoProvider * const provider = [[StaticInfoProvider alloc] initWithDictionary :
                                                      (NSDictionary *)dictBase];

               MenuItem * const newItem = [[MenuItem alloc] initWithContentProvider : provider];
               [subMenu addObject : newItem];
              
            }

            assert([itemDict[@"Title"] isKindOfClass : [NSString class]] &&
                   "loadStaticInfo:, 'Title' is either nil or has a wrong type");
            MenuItemsGroup * const newGroup = [[MenuItemsGroup alloc] initWithTitle : (NSString *)itemDict[@"Title"]
                                               image : [self loadItemImage : itemDict] items : subMenu];
            [items addObject : newGroup];
         } else {
            StaticInfoProvider * const provider = [[StaticInfoProvider alloc] initWithDictionary : itemDict];
            MenuItem * const newItem = [[MenuItem alloc] initWithContentProvider : provider];
            [items addObject : newItem];
         }
      }
      
      [self addMenuGroup : @"About CERN" withImage : [self loadItemImage : desc] forItems : items];
      [self setStateForGroup : menuItems.count - 1 from : desc];
   }
   
   return YES;
}

//________________________________________________________________________________________
- (void) setMenuGeometryHints
{
   CGFloat whRatio = 0.f;

   for (NSObject<MenuItemProtocol> *menuItem in menuItems) {
      if (UIImage * const image = menuItem.itemImage) {
         const CGSize size = image.size;
         assert(size.width > 0.f && size.height > 0.f &&
                "setMenuGeometryHints, invalid image size");
         const CGFloat currRatio = size.width / size.height;
         if (currRatio > whRatio)
            whRatio = currRatio;
      }
   }
   
   CGSize imageHint = {};
   if (whRatio) {
      imageHint.width = CernAPP::groupMenuItemImageHeight * whRatio;
      imageHint.height = CernAPP::groupMenuItemImageHeight;
   }
   
   for (NSObject<MenuItemProtocol> *menuItem in menuItems) {
      //indent == 0.f - these are top-level menu items.
      [menuItem setIndent : 0.f imageHint : imageHint];
   }
}

//________________________________________________________________________________________
- (void) loadMenuContents
{
   assert(inAnimation == NO && "loadMenuContents, called while animation is active");
   assert(menuPlist != nil && "loadMenuContents, menuPlist is nil");

   if (menuItems && menuItems.count) {
      for (NSObject<MenuItemProtocol> *item in menuItems)
         [item deleteItemView];
      [menuItems removeAllObjects];
   } else
      menuItems = [[NSMutableArray alloc] init];
   
   selectedItemView = nil;

   id objBase = menuPlist[@"Menu Contents"];
   assert(objBase != nil && "loadMenuContents, object for the key 'Menu Contents was not found'");
   assert([objBase isKindOfClass : [NSArray class]] &&
          "loadMenuContents, menu contents must be of a NSArray type");
          
   NSArray * const menuContents = (NSArray *)objBase;
   assert(menuContents.count != 0 && "loadMenuContents, menu contents array is empty");
   
   for (id entryBase in menuContents) {
      assert([entryBase isKindOfClass : [NSDictionary class]] &&
             "loadMenuContents, NSDictionary expected for menu item(s)");
      
      //Menu-groups:
      if ([self loadMenuGroup : (NSDictionary *) entryBase])
         continue;
      if ([self loadLIVESection : (NSDictionary *)entryBase])
         continue;
      if ([self loadStaticInfo : (NSDictionary *)entryBase])
         continue;

      //Stand-alone non-group items:
      if ([self loadSpecialItem : (NSDictionary *)entryBase])
         continue;
      if ([self loadSeparator : (NSDictionary *)entryBase])
         continue;
      if ([self loadBulletin : (NSDictionary *)entryBase into : menuItems])
         continue;
      if ([self loadPhotoSet : (NSDictionary *)entryBase into : menuItems])
         continue;
      if ([self loadVideoSet : (NSDictionary *)entryBase into : menuItems])
         continue;
      //Webcasts.
   }
   
   [self setMenuGeometryHints];
}

//________________________________________________________________________________________
- (void) layoutMenuResetOffset : (BOOL) resetOffset resetContentSize : (BOOL) resetContentSize
{
   CGRect currentFrame = {0.f, 0.f, scrollView.frame.size.width};
   CGFloat totalHeight = 0.f;
   
   for (NSObject<MenuItemProtocol> *item in menuItems) {
      const CGFloat add = [item layoutItemViewWithHint : currentFrame];
      totalHeight += add;
      currentFrame.origin.y += add;
   }

   if (resetOffset && scrollView.contentOffset.y) {
      if (selectedItemView) {
         const CGRect visibleRect = [selectedItemView.superview convertRect : selectedItemView.frame toView : scrollView];
         [scrollView scrollRectToVisible : visibleRect animated : NO];
      } else
         scrollView.contentOffset = CGPoint();
   }

   if (resetContentSize)
      scrollView.contentSize = CGSizeMake(scrollView.frame.size.width, totalHeight);
}

#pragma mark - View lifecycle's management + settings notifications.

//________________________________________________________________________________________
- (void) awakeFromNib
{
   inAnimation = NO;
   newOpen = nil;
   updateStage = MenuUpdateStage::none;
}

//________________________________________________________________________________________
- (void) dealloc
{
   [[NSNotificationCenter defaultCenter] removeObserver : self];
}

//________________________________________________________________________________________
- (void) defaultsChanged : (NSNotification *) notification
{
   if ([notification.object isKindOfClass : [NSUserDefaults class]]) {
      NSUserDefaults * const defaults = (NSUserDefaults *)notification.object;
      if (id sz = [defaults objectForKey : @"GUIFontSize"]) {
         assert([sz isKindOfClass : [NSNumber class]] && "defaultsChanged:, GUIFontSize has a wrong type");
         const CGFloat newFontSize = [(NSNumber *)sz floatValue];
         
         for (NSObject<MenuItemProtocol> * item in menuItems)
            [item setLabelFontSize : newFontSize];
         
         [self layoutMenuResetOffset : NO resetContentSize : NO];
      }
   }
}

//________________________________________________________________________________________
- (void) viewDidLoad
{
   [super viewDidLoad];
   
   [self.slidingViewController setAnchorRightRevealAmount : 280.f];
   self.slidingViewController.underLeftWidthLayout = ECFullWidth;
   
   //We additionally setup a table view here.
   using CernAPP::menuBackgroundColor;
   scrollView.backgroundColor = [UIColor colorWithRed : menuBackgroundColor[0] green : menuBackgroundColor[1]
                                         blue : menuBackgroundColor[2] alpha : 1.f];
   scrollView.showsHorizontalScrollIndicator = NO;
   scrollView.showsVerticalScrollIndicator = NO;
   
   selectedItemView = nil;

   menuPlist = LoadOfflineMenuPlist(@"MENU");
   livePlist = LoadOfflineMenuPlist(@"CERNLive");
   [self loadMenuContents];
   
   //Settings modifications.
   [[NSNotificationCenter defaultCenter] addObserver : self selector : @selector(defaultsChanged:) name : NSUserDefaultsDidChangeNotification object : nil];
   
   //TODO: We also have to subscribe for push notifications here - the 'MENU.plist' on a server can be updated.
   [self updateMenuFromServer];
}

//________________________________________________________________________________________
- (void) viewDidLayoutSubviews
{
   [self layoutMenuResetOffset : YES resetContentSize : YES];
}

#pragma mark - Menu animations.

//________________________________________________________________________________________
- (void) itemViewWasSelected : (MenuItemView *) view
{
   assert(view != nil && "itemViewWasSelected:, parameter 'view' is nil");

   if (selectedItemView) {
      selectedItemView.isSelected = NO;
      [selectedItemView setNeedsDisplay];
   }
   
   selectedItemView = view;
   selectedItemView.isSelected = YES;
   [selectedItemView setNeedsDisplay];
}

//________________________________________________________________________________________
- (void) groupViewWasTapped : (MenuItemsGroupView *) view
{
   assert(view != nil && "groupViewWasTapped:, parameter 'view' is nil");

   if (inAnimation)
      return;
   
   MenuItemsGroup * const group = view.menuItemsGroup;
   newOpen = nil;

   if (!group.parentGroup) {
      //When we expand/collapse a sub-menu, we have to also adjust our
      //scrollview - scroll to this sub-menu (if it's opened) or another
      //opened sub-menu (above or below the selected sub-menu).
      for (NSUInteger i = 0, e = menuItems.count; i < e; ++i) {
         NSObject<MenuItemProtocol> * const itemBase = (NSObject<MenuItemProtocol> *)menuItems[i];
         if (![itemBase isKindOfClass : [MenuItemsGroup class]])
            continue;//We scroll only to open sub-menus.

         MenuItemsGroup * const currGroup = (MenuItemsGroup *)itemBase;
         if (currGroup != group) {
            if (!currGroup.collapsed)
               newOpen = currGroup;//Index of open sub-menu above our selected sub-menu.
         } else {
            if (group.collapsed)//Group is collapsed, now will become open.
               newOpen = group;//It's our sub-menu who's open.
            else {
               //Group was open, now will collapse.
               //Do we have any open sub-menus at all?
               if (!newOpen) {//Nothing was open above our sub-menu. Search for the first open below.
                  for (NSUInteger j = i + 1; j < e; ++j) {
                     if ([menuItems[j] isKindOfClass : [MenuItemsGroup class]]) {
                        if (!((MenuItemsGroup *)menuItems[j]).collapsed) {
                           newOpen = (MenuItemsGroup *)menuItems[j];
                           break;
                        }
                     }
                  }
               }
            }
            
            break;
         }
      }
   } else
      newOpen = group.parentGroup;//We have to focus on group's parent group.
   
   [self animateMenuForItem : group];
}

//________________________________________________________________________________________
- (void) setAlphaAndVisibilityForGroup : (MenuItemsGroup *) group
{
   //During animation, if view will appear it's alpha changes from 0.f to 1.f,
   //and if it's going to disappear - from 1.f to 0.f.
   //Also, I have to animate small triangle, which
   //shows group's state (expanded/collapsed).
   
   assert(group != nil && "setAlphaAndVisibilityForGroup:, parameter 'group' is nil");
   
   if (group.containerView.hidden) {
      if (!group.collapsed) {
         group.containerView.hidden = NO;
         group.groupView.alpha = 1.f;
         //Triangle animation.
         group.titleView.discloseImageView.transform = CGAffineTransformMakeRotation(0.f);//rotate the triangle.
      }
   } else if (group.collapsed) {
      group.groupView.alpha = 0.f;
      //Triangle animation.
      group.titleView.discloseImageView.transform = CGAffineTransformMakeRotation(-M_PI / 2);//rotate the triangle.
   }
}

//________________________________________________________________________________________
- (void) adjustMenu
{
   assert(inAnimation == YES && "adjustMenu, can be called only during an animation");

   //Content view size.
   CGFloat totalHeight = 0.f;

   for (NSObject<MenuItemProtocol> *menuItem in menuItems) {
      if ([menuItem isKindOfClass:[MenuItemsGroup class]]) {
         if (((MenuItemsGroup *)menuItem).collapsed) {
            totalHeight += CernAPP::GroupMenuItemHeight();
            continue;
         }
      }

      totalHeight += [menuItem requiredHeight];
   }

   scrollView.contentSize = CGSizeMake(scrollView.frame.size.width, totalHeight);
   
   CGRect frameToShow = CGRectMake(0.f, 0.f, scrollView.frame.size.width, CernAPP::GroupMenuItemHeight());

   if (newOpen != nil) {
      if (!newOpen.parentGroup)
         frameToShow = newOpen.containerView.frame;
      else
         frameToShow = newOpen.parentGroup.containerView.frame;
      
      frameToShow.origin.y -= CernAPP::GroupMenuItemHeight();
      frameToShow.size.height += CernAPP::GroupMenuItemHeight();
   }

   [scrollView scrollRectToVisible : frameToShow animated : YES];
   inAnimation = NO;
}

//________________________________________________________________________________________
- (void) hideGroupViews
{
   for (NSObject<MenuItemProtocol> *itemBase in menuItems) {
      if ([itemBase isKindOfClass : [MenuItemsGroup class]]) {
         MenuItemsGroup * const group = (MenuItemsGroup *)itemBase;
         for (NSUInteger i = 0, e = group.nItems; i < e; ++i) {
            NSObject<MenuItemProtocol> * const nested = [group item : i];
            if ([nested isKindOfClass : [MenuItemsGroup class]]) {
               MenuItemsGroup * const nestedGroup = (MenuItemsGroup *)nested;
               nestedGroup.containerView.hidden = nestedGroup.collapsed;
            }
         }

         group.containerView.hidden = group.collapsed;
      }
   }
}

//________________________________________________________________________________________
- (void) animateMenuForItem : (MenuItemsGroup *) groupItem
{
   //'groupItem' has just changed it's state.

   assert(groupItem != nil && "animateMenuForItem:, parameter 'groupItem' is nil");
   assert(inAnimation == NO && "animateMenu, called during active animation");

   inAnimation = YES;

   [self layoutMenuResetOffset : NO resetContentSize : NO];//Set menu items before the animation.

   //Now, change the state of menu item.
   groupItem.collapsed = !groupItem.collapsed;

   [UIView animateWithDuration : 0.25f animations : ^ {
      [self layoutMenuResetOffset : NO resetContentSize : YES];//Layout menu again, but with different positions for groupItem (and it's children).
      [self setAlphaAndVisibilityForGroup : groupItem];
   } completion : ^ (BOOL) {
      [self hideGroupViews];
      [self adjustMenu];
   }];
}

#pragma mark - Code to read CERNLive.plist.

//This code is taken from CERN.app v.1. It somehow duplicates
//loadNewsSection. This part can be TODO: refactored.

//________________________________________________________________________________________
- (bool) readLIVENewsFeeds : (NSArray *) feeds
{
   assert(feeds != nil && "readNewsFeeds:, parameter 'feeds' is nil");

   bool result = false;
   
   for (id info in feeds) {
      assert([info isKindOfClass : [NSDictionary class]] && "readNewsFeed, feed info must be a dictionary");
      NSDictionary * const feedInfo = (NSDictionary *)info;
      FeedProvider * const provider = [[FeedProvider alloc] initWith : feedInfo];
      [liveData addObject : provider];
      result = true;
   }
   
   return result;
}

//________________________________________________________________________________________
- (bool) readLIVENews : (NSDictionary *) dataEntry
{
   assert(dataEntry != nil && "readNews:, parameter 'dataEntry' is nil");

   id base = [dataEntry objectForKey : @"Category name"];
   assert(base != nil && [base isKindOfClass : [NSString class]] && "readNews:, string key 'Category name' was not found");

   bool result = false;
   
   NSString *catName = (NSString *)base;
   if ([catName isEqualToString : @"News"]) {
      if ((base = [dataEntry objectForKey : @"Feeds"])) {
         assert([base isKindOfClass : [NSArray class]] && "readNews:, object for 'Feeds' key must be of an array type");
         result = [self readLIVENewsFeeds : (NSArray *)base];
      }

      if ((base = [dataEntry objectForKey : @"Tweets"])) {
         assert([base isKindOfClass : [NSArray class]] && "readNews:, object for 'Tweets' key must be of an array type");
         result |= [self readLIVENewsFeeds : (NSArray *)base];
      }
   }
   
   return result;
}

//________________________________________________________________________________________
- (bool) readLIVEImages : (NSDictionary *) dataEntry experiment : (CernAPP::LHCExperiment) experiment
{
   assert(dataEntry != nil && "readLIVEImages, parameter 'dataEntry' is nil");

   if (dataEntry[@"Images"]) {
      assert([dataEntry[@"Images"] isKindOfClass : [NSArray class]] &&
             "readLIVEImages:, object for 'Images' key must be of NSArray type");
      NSArray *images = (NSArray *)dataEntry[@"Images"];
      assert(images.count && "readLIVEImages, array of images is empty");
      
      LiveEventsProvider * const provider = [[LiveEventsProvider alloc] initWith : images forExperiment : experiment];
      [liveData addObject : provider];
      
      if (dataEntry[@"Category name"]) {
         assert([dataEntry[@"Category name"] isKindOfClass : [NSString class]] &&
                "readLIVEImages, 'Category Name' for the data entry is not of NSString type");
         provider.categoryName = (NSString *)dataEntry[@"Category name"];
      }

      return true;
   }
   
   return false;
}

//________________________________________________________________________________________
- (void) readLIVEData : (NSDictionary *) desc
{
   assert(desc != nil && "readLIVEData:, parameter 'desc' is nil");
   assert(livePlist != nil && "readLIVEData:, livePlist is nil");
   assert([livePlist[@"Root"] isKindOfClass : [NSArray class]] &&
          "readLIVEData:, 'Root' not found or has a wrong type");

   NSArray * const liveItems = (NSArray *)livePlist[@"Root"];
   
   NSMutableArray * const menuGroups = [[NSMutableArray alloc] init];

   for (id obj in liveItems) {
      assert([obj isKindOfClass : [NSDictionary class]] &&
             "readLIVEData:, NSDictionary was expected");
      
      NSDictionary * const itemData = (NSDictionary *)obj;
      assert([itemData[@"ExperimentName"] isKindOfClass:[NSString class]] &&
             "readLIVEData:, 'ExperimentName' not found or has a wrong type");
      NSString * const experimentName = (NSString *)itemData[@"ExperimentName"];
      const CernAPP::LHCExperiment experiment = CernAPP::ExperimentNameToEnum(experimentName);

      id base = itemData[@"Data"];
      assert([base isKindOfClass : [NSArray class]] && "readLIVEData:, 'Data' not found or has a wrong type");

      NSArray * const dataSource = (NSArray *)base;
   
      liveData = [[NSMutableArray alloc] init];
      for (id arrayItem in dataSource) {
         assert([arrayItem isKindOfClass : [NSDictionary class]] && "readLIVEData:, array of dictionaries expected");
         NSDictionary * const data = (NSDictionary *)arrayItem;
         
         if ([self readLIVENews : data])
            continue;
         
         if ([self readLIVEImages : data experiment : experiment])
            continue;
         
         //someting else can be here.
      }
      
      NSMutableArray * const liveMenuItems = [[NSMutableArray alloc] init];
      for (NSObject<ContentProvider> *provider in liveData) {
         MenuItem * newItem = [[MenuItem alloc] initWithContentProvider : provider];
         [liveMenuItems addObject : newItem];
      }
      
      if (experiment == CernAPP::LHCExperiment::ALICE) {
         //We do not have real live events for ALICE, we just have a set
         //of good looking images :)
         NSDictionary * const photoSet = @{@"Name" : @"Events", @"Url" : @"https://cdsweb.cern.ch/record/1305399/export/xm?ln=en"};
         PhotoSetProvider * const edProvider = [[PhotoSetProvider alloc] initWithDictionary : photoSet];
         MenuItem * const newItem = [[MenuItem alloc] initWithContentProvider : edProvider];
         [liveMenuItems addObject : newItem];
      }
      
      MenuItemsGroup * newGroup = [[MenuItemsGroup alloc] initWithTitle : experimentName image : nil items : liveMenuItems];
      [menuGroups addObject : newGroup];
   }
   
   [self addMenuGroup : @"LIVE" withImage : [self loadItemImage : desc] forItems : menuGroups];
   [self setStateForGroup : menuItems.count - 1 from : desc];
}

#pragma mark - Update the menu using the remote MENU.plist + NSURLConnection delegate.
//________________________________________________________________________________________
- (void) updateMenuFromServer
{
   if (updateStage != MenuUpdateStage::none) {
      //In principle, this can happen: server in future will be sending
      //update notifications, and if we are already updating ...
      
      //TODO: this should be checked and tested.
      [self performSelector : @selector(updateMenuFromServer) withObject : nil afterDelay : 5.f];
      return;
   }

   menuData = [[NSMutableData alloc] init];
   updateStage = MenuUpdateStage::menuPlistUpdate;
   connection = [[NSURLConnection alloc] initWithRequest : [NSURLRequest requestWithURL : [NSURL URLWithString : @"http://cernapp.cern.ch/MENU.plist"]]
                                                delegate : self];
}

//________________________________________________________________________________________
- (void) updateMenuLIVEFromServer
{
   assert(updateStage == MenuUpdateStage::menuPlistUpdate && "updateMenuLIVEFromServer, wrong stage");
   
   menuData = [[NSMutableData alloc] init];

   updateStage = MenuUpdateStage::livePlistUpdate;
   connection = [[NSURLConnection alloc] initWithRequest : [NSURLRequest requestWithURL : [NSURL URLWithString : @"http://cernapp.cern.ch/CERNLive.plist"]]
                                                delegate : self];
}

//________________________________________________________________________________________
- (void) connection : (NSURLConnection *) aConnection didReceiveData : (NSData *) data
{
   assert(aConnection != nil && "connection:didReceiveData:, parameter 'aConnection' is nil");
   assert(data != nil && "connection:didReceiveData:, parameter 'data' is nil");
   //assert(menuData != nil && "connection:didReceiveData:, menuData is nil");
   if (connection != aConnection) {
      //I do not think this can ever happen :)
      NSLog(@"imageDownloader, error: connection:didReceiveData:, data from unknown connection");
      return;
   }
   
   [menuData appendData : data];
}

//________________________________________________________________________________________
- (void) connection : (NSURLConnection *) aConnection didFailWithError : (NSError *) error
{
#pragma unused(error)
   assert(aConnection != nil && "connection:didFailWithError:, parameter 'aConnection' is nil");

   if (connection != aConnection) {
      //Can this ever happen?
      NSLog(@"imageDownloader, error: connection:didFaileWithError:, unknown connection");
      return;
   }
   
   menuData = nil;
   connection = nil;//Can I do this??? (I'm in a callback function now)
}

//________________________________________________________________________________________
- (void) connectionDidFinishLoading : (NSURLConnection *) aConnection
{
   assert(aConnection != nil && "connectionDidFinishLoading:, parameter 'aConnection' is nil");
   assert(updateStage != MenuUpdateStage::none && "connectionDidFinishLoading:, wrong stage");
   
   if (connection != aConnection) {
      NSLog(@"imageDownloader, error: connectionDidFinishLoading:, unknown connection");
      return;
   }

   connection = nil;//Can I do this??? (I'm in a callback function now)

   NSError *err = nil;
   NSPropertyListFormat format = NSPropertyListXMLFormat_v1_0;
   id obj = nil;
   
   if (menuData.length)
      obj = [NSPropertyListSerialization propertyListWithData : menuData options : NSPropertyListImmutable format : &format error : &err];

   //
   menuData = nil;
   //

   if (obj && !err && [obj isKindOfClass : [NSDictionary class]]) {
      if (updateStage == MenuUpdateStage::menuPlistUpdate) {
         menuPlist = (NSDictionary *)obj;
         WriteOfflineMenuPlist(menuPlist, @"MENU.plist");
         [self updateMenuLIVEFromServer];
      } else {
         livePlist = (NSDictionary *)obj;
         WriteOfflineMenuPlist(livePlist, @"CERNLive.plist");
         //Reload
         [self reloadMenuAfterAnimationFinished];
      }
   } else {
      if (updateStage == MenuUpdateStage::menuPlistUpdate) {
         [self updateMenuLIVEFromServer];
      } else {
         [self reloadMenuAfterAnimationFinished];
      }
   }
}

//________________________________________________________________________________________
- (void) reloadMenuAfterAnimationFinished
{
   if (inAnimation)//We have to wait.
      [self performSelector : @selector(reloadMenuAfterAnimationFinished) withObject : nil afterDelay : 0.5f];
   else {
      [self loadMenuContents];
      [self layoutMenuResetOffset : YES resetContentSize : YES];
   }
}

@end
