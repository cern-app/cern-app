//
//  PhotoDownloader.h
//  CERN App
//
//  Created by Eamon Ford on 7/4/12.
//  Copyright (c) 2012 CERN. All rights reserved.
//

//The code was modified/fixed to at least some working state by Timur Pocheptsov.

#import <Foundation/Foundation.h>
#import "CernMediaMARCParser.h"

@class PhotoDownloader;

@protocol PhotoDownloaderDelegate <NSObject>
@optional
- (void) photoDownloaderDidFinishLoadingThumbnails : (PhotoDownloader *) photoDownloader;
- (void) photoDownloaderDidFinish : (PhotoDownloader *) photoDownloader;
- (void) photoDownloader : (PhotoDownloader *) photoDownloader didDownloadThumbnail : (NSUInteger) imageIndex forSet : (NSUInteger) setIndex;
- (void) photoDownloader : (PhotoDownloader *) photoDownloader didFailWithError : (NSError *) error;
@end

//
//First, we parse some xml file (done by CernMediaMARCParser).
//We got a number of records - or photo sets.
//Each photoset has a number of images inside.
//Invariant: there is no empty phothosets.
//After xml was parsed, we'll inform a delegate.
//Delegate asks the number of photosets (this will be the number of sections in a collection view),
//and the number of items in a photoset (number of cells in a section of a collection view).
//Now, we try to download images. PhotoDownloader informs its delegate about every image downloaded
//(and UICollectionViewController, if it is our delegate, will immediately show this image in its
//collection view). It's possible, that some images were not downloaded (errors).
//That's why, after all photosets are downloaded, we inform a delegate, and call 'compactData',
//which removes failed image records. After that, collectionView can be reloaded, if needed.
//PhotoDownloader itself ONLY downloads thumbnails, not real images (this is done by
//MWPhotoBrowser later).
//

@interface PhotoSet : NSObject {
   NSMutableArray *images;
}

@property (nonatomic) NSString *title;


- (void) addImageData : (NSDictionary *) dict;
- (UIImage *) getThumbnailImageForIndex : (NSUInteger) index;
- (void) setThumbnailImage : (UIImage *) image withIndex : (NSUInteger) index;
- (NSURL *) getImageURLWithIndex : (NSUInteger) index forType : (NSString *) type;

- (NSUInteger) nImages;
- (void) compactPhotoSet;

@end

@interface PhotoDownloader : NSObject<CernMediaMarcParserDelegate, NSURLConnectionDataDelegate>

- (void) parse;
- (void) stop;

- (void) compactData;

@property (nonatomic, readonly) NSMutableArray *photoSets;
@property (nonatomic, strong) NSURL *url;
@property (nonatomic) __weak id<PhotoDownloaderDelegate> delegate;
@property (nonatomic, assign) BOOL isDownloading;

- (bool) hasConnection;

@end
