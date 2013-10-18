//
//  MWPhotoBrowser.h
//  MWPhotoBrowser
//
//  Created by Michael Waterfall on 14/10/2010.
//  Copyright 2010 d3i. All rights reserved.
//

#import <MessageUI/MessageUI.h>
#import <UIKit/UIKit.h>

#import "PhotoBrowserProtocol.h"
#import "MWPhotoProtocol.h"
#import "MWCaptionView.h"
#import "MWPhoto.h"

// Debug Logging
#if 0 // Set to 1 to enable debug logging
#define MWLog(x, ...) NSLog(x, ## __VA_ARGS__);
#else
#define MWLog(x, ...)
#endif

// Delegate
@class MWPhotoBrowser;

@protocol MWPhotoBrowserDelegate <NSObject>

- (NSUInteger)numberOfPhotosInPhotoBrowser:(MWPhotoBrowser *)photoBrowser;
- (id<MWPhoto>)photoBrowser:(MWPhotoBrowser *)photoBrowser photoAtIndex:(NSUInteger)index;
- (void) photoBrowserWillDismiss;

@optional

- (MWCaptionView *)photoBrowser:(MWPhotoBrowser *)photoBrowser captionViewForPhotoAtIndex:(NSUInteger)index;

@end

//
//MWPhotoBrowser
//
@interface MWPhotoBrowser : UIViewController <UIScrollViewDelegate, UIActionSheetDelegate,
                                              MFMailComposeViewControllerDelegate,
                                              PhotoBrowserProtocol>
// Properties
@property (nonatomic) BOOL displayActionButton;

// Init
- (id) initWithPhotos : (NSArray *) photosArray  __attribute__((deprecated)); // Depreciated
- (id) initWithDelegate : (id <MWPhotoBrowserDelegate>) delegate;

// Reloads the photo browser and refetches data
- (void) reloadData;

// Set page that photo browser starts on
- (void) setInitialPageIndex : (NSUInteger) index;

@end


