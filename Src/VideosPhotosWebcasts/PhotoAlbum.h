//
//  PhotoAlbum.h
//  CERN
//
//  Created by Timur Pocheptsov on 5/17/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ImageDownloader.h"

namespace CernAPP {

extern NSString * const ResourceTypeThumbnail;

}

//PhotoAlbum - set of images (info about images).
@interface PhotoAlbum : NSObject<ImageDownloaderDelegate>

@property (nonatomic) NSString *title;

- (void) addImageData : (NSDictionary *) dict;
- (UIImage *) getThumbnailImageForIndex : (NSUInteger) index;
- (void) setThumbnailImage : (UIImage *) image withIndex : (NSUInteger) index;
- (NSURL *) getImageURLWithIndex : (NSUInteger) index forType : (NSString *) type;

- (NSUInteger) nImages;

- (void) loadFirstThumbnailWithDelegate : (NSObject<ImageDownloaderDelegate> *) delegate;
- (void) loadThumbnailsWithDelegate : (NSObject<ImageDownloaderDelegate> *) delegate;

@end
