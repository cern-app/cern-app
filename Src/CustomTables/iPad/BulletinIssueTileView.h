//
//  BulletinIssueTileView.h
//  CERN
//
//  Created by Timur Pocheptsov on 4/9/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BulletinIssueTileView : UIView

+ (CGFloat) minImageSize;

@property (nonatomic) BOOL wideImageOnTopHint;
@property (nonatomic) BOOL squareImageOnLeftHint;

@property (nonatomic) NSUInteger issueNumber;

//Thumbnail sizes must be >= minImageSize.
//Returns YES if image is big enough, otherwise NO.
- (BOOL) setThumbnailImage : (UIImage *) thumbnail;
- (BOOL) hasThumbnailImage;
- (void) setTileText : (NSString *) text;

- (void) layoutContents;

@end

namespace CernAPP {

extern NSString * const bulletinIssueSelectionNotification;

}
