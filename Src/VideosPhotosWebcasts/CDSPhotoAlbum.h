//
//  CDSPhotoAlbum.h
//  CERN
//
//  Created by Timur Pocheptsov on 10/3/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <Foundation/Foundation.h>

namespace CernAPP {

//Different sizes (for the same image).
//Strings, as they work as keys in a dictionary.
extern NSString * const thumbnailImage;
extern NSString * const iPhoneImage;
extern NSString * const iPadImage;

}

//CDS photo album - collection of images (different urls for images).
@interface CDSPhotoAlbum : NSObject

- (void) addImageData : (NSDictionary *) dict;
- (UIImage *) getThumbnailImageForIndex : (NSUInteger) index;
- (void) setThumbnailImage : (UIImage *) image withIndex : (NSUInteger) index;
- (NSURL *) getImageURLWithIndex : (NSUInteger) index forSize : (NSString *) type;

- (NSUInteger) nImages;

@property (nonatomic) NSString *title;

@end