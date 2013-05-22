//
//  PhotoAlbum.h
//  CERN
//
//  Created by Timur Pocheptsov on 5/17/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <Foundation/Foundation.h>

namespace CernAPP {

extern NSString * const ResourceTypeThumbnail;
extern NSString * const ResourceTypeThumbnailImage;
extern NSString * const ResourceTypeImageForPhotoBrowserIPAD;

}

//PhotoAlbum - set of images (info about images).
@interface PhotoAlbum : NSObject

@property (nonatomic) NSString *title;

- (void) addImageData : (NSDictionary *) dict;
- (UIImage *) getThumbnailImageForIndex : (NSUInteger) index;
- (void) setThumbnailImage : (UIImage *) image withIndex : (NSUInteger) index;
- (NSURL *) getImageURLWithIndex : (NSUInteger) index forType : (NSString *) type;

- (NSUInteger) nImages;

@end
