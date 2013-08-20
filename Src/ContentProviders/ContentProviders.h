#import <Foundation/Foundation.h>

#import "Experiments.h"

//
//The base class for content providers.
//
@protocol ContentProvider <NSObject>
@optional

- (UIImage *) categoryImage;
- (void) loadControllerTo : (UIViewController *) controller;

@property (nonatomic, retain) NSString *categoryName;
@property (nonatomic) NSUInteger providerID;

@end

//
//I'm using this class, at the moment, for news feeds and tweets.
//
@interface FeedProvider : NSObject<ContentProvider, UIActionSheetDelegate>

- (id) initWith : (NSDictionary *) feedInfo;

@property (nonatomic, retain) NSString *categoryName;
@property (nonatomic) NSUInteger providerID;

- (UIImage *) categoryImage;

- (void) loadControllerTo : (UIViewController *) controller;

@end

@interface PhotoSetProvider : NSObject<ContentProvider>

- (id) initWithDictionary : (NSDictionary *) info;

@property (nonatomic, retain) NSString *categoryName;

- (UIImage *) categoryImage;

- (void) loadControllerTo : (UIViewController *) controller;

@end

//
//This is class to keep references and names for Live Events.
//
@interface LiveEventsProvider : NSObject<ContentProvider>

- (id) initWith : (NSArray *) dataEntry forExperiment : (CernAPP::LHCExperiment) experiment;

@property (nonatomic, retain) NSString *categoryName;

- (UIImage *) categoryImage;

- (void) loadControllerTo : (UIViewController *) controller;
- (void) pushEventDisplayInto : (UINavigationController *) controller selectedImage : (NSInteger) selected;

@end

//
//Info about live event image.
//
@interface LiveImageData : NSObject

- (id) initWithName : (NSString *) name url : (NSString *) imageUrl bounds : (CGRect) imageBounds;

@property (nonatomic, readonly) NSString *imageName;
@property (nonatomic, readonly) NSString *url;
@property (nonatomic, retain) UIImage *image;
@property (nonatomic, readonly) CGRect bounds;

@end

//
//CERN Bulletin.
//
@interface BulletinProvider : NSObject<ContentProvider>

- (id) initWithDictionary : (NSDictionary *) info;

@property (nonatomic, retain) NSString *categoryName;
@property (nonatomic) NSUInteger providerID;

- (UIImage *) categoryImage;

- (void) loadControllerTo : (UIViewController *) controller;

@end

@interface StaticInfoProvider : NSObject<ContentProvider>

- (id) initWithDictionary : (NSDictionary *) info;

@property (nonatomic, retain) NSString *categoryName;

- (UIImage *) categoryImage;

- (void) loadControllerTo : (UIViewController *) controller;

@end

//
//Videos.
//

@interface LatestVideosProvider : NSObject<ContentProvider>

- (id) initWithDictionary : (NSDictionary *) info;

@property (nonatomic, retain) NSString *categoryName;

- (UIImage *) categoryImage;

- (void) loadControllerTo : (UIViewController *) controller;

@end

//
//Content provider for a modal view controller.
//

@interface ModalViewProvider : NSObject<ContentProvider>

- (id) initWithDictionary : (NSDictionary *) info;
@property (nonatomic, retain) NSString *categoryName;
@property (nonatomic) NSUInteger providerID;
- (UIImage *) categoryImage;
- (void) loadControllerTo : (UIViewController *) controller;

@end

//
//Content provider for a navigation view controller.
//

@interface NavigationViewProvider : NSObject<ContentProvider>

- (id) initWithDictionary : (NSDictionary *) dict;

@property (nonatomic, retain) NSString *categoryName;

- (UIImage *) categoryImage;
- (void) loadControllerTo : (UIViewController *) controller;

@end
