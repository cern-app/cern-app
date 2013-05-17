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
@interface PhotoAlbum : NSObject

@property (nonatomic) NSString *title;

- (void) addImageData : (NSDictionary *) dict;
- (UIImage *) getThumbnailImageForIndex : (NSUInteger) index;
- (void) setThumbnailImage : (UIImage *) image withIndex : (NSUInteger) index;
- (NSURL *) getImageURLWithIndex : (NSUInteger) index forType : (NSString *) type;

- (NSUInteger) nImages;

@end

//Load thumbnail images for a photo album
//(only one, if an album has a 'stacked' style.
@interface PhotoAlbumThumbnailDownloader : NSObject<ImageDownloaderDelegate>

- (void) loadFirstThumbnailForAlbum : (PhotoAlbum *) album delegate : (NSObject<ImageDownloaderDelegate> *) delegate;
- (void) loadThumbnailsForAlbum : (PhotoAlbum *) album delegate : (NSObject<ImageDownloaderDelegate> *) delegate;

@end
