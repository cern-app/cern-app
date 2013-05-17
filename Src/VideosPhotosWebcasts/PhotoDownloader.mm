//
//  PhotoDownloader.m
//  CERN App
//
//  Created by Eamon Ford on 7/4/12.
//  Copyright (c) 2012 CERN. All rights reserved.
//

//The code was modified/fixed to at least some working state by Timur Pocheptsov.

#import <cassert>

#import "UIImage+SquareScaledImage.h"
#import "PhotoDownloader.h"
#import "Reachability.h"

using CernAPP::NetworkStatus;


//If I do not have a thumbnail (load error) - I do not show this item in a collection view.
//TODO: better logic can be used for such errors.

///////

@implementation PhotoSet

@synthesize title;

//________________________________________________________________________________________
- (id) init
{
   if (self = [super init])
      images = [[NSMutableArray alloc] init];
   
   return self;
}

//________________________________________________________________________________________
- (void) addImageData : (NSDictionary *) dict
{
   assert(dict != nil && "addImageRecord:, parameter 'dict' is nil");

   //TODO: remove this check!
   id copy = [dict mutableCopy];
   assert([copy isKindOfClass : [NSDictionary class]] && "addImageData:, bad assumption about type :)");
   
   [images addObject : copy];
}

//________________________________________________________________________________________
- (UIImage *) getThumbnailImageForIndex : (NSUInteger) index
{
   assert(index < images.count && "getThumbnailImageForIndex, parameter 'index' is out of bounds");
   
   NSDictionary * const imageData = (NSDictionary *)images[index];
   return (UIImage *)imageData[@"Thumbnail"];
}

//________________________________________________________________________________________
- (void) setThumbnailImage : (UIImage *) image withIndex : (NSUInteger) index
{
   assert(image != nil && "setThumbnailImage:withIndex:, parameter 'image' is nil");
   assert(index < images.count && "setThumbnailImage:withIndex:, parameter 'index' is out of bounds");
   
   NSMutableDictionary * const imageDict = (NSMutableDictionary *)images[index];
   [imageDict setObject : image forKey : @"Thumbnail"];
}

//________________________________________________________________________________________
- (NSURL *) getImageURLWithIndex : (NSUInteger) index forType : (NSString *) type
{
   assert(index < images.count && "getImageURLWithIndex:forType:, parameter 'index' is out of bounds");
   assert(type != nil && "getImageURLWithIndex:forType:, parameter 'type' is nil");
   
   NSDictionary * const imageData = images[index];
   assert(imageData[type] != nil &&
          "getImageURLWithIndex:forType:, no url for resource type found");
   
   return (NSURL *)imageData[type];
}

//________________________________________________________________________________________
- (NSUInteger) nImages
{
   return images.count;
}

//________________________________________________________________________________________
- (void) compactPhotoSet
{
   if (images.count) {
      //Wow!
      NSPredicate * const predicate = [NSPredicate predicateWithBlock : ^ BOOL (id evaluatedObject, NSDictionary *bindings) {
         assert([evaluatedObject isKindOfClass : [NSDictionary class]]);
         return [(NSDictionary *)evaluatedObject objectForKey : @"Thumbnail"] != nil;
      }];

      [images filterUsingPredicate : predicate];
   }
}

@end

@implementation PhotoDownloader {
   CernMediaMARCParser *parser;

   NSUInteger photoSetToLoad;
   NSUInteger imageToLoad;
   NSMutableData *thumbnailData;
   NSURLConnection *currentConnection;

   Reachability *internetReach;
}

@synthesize photoSets, delegate, isDownloading;

#pragma mark - Reachability.

//________________________________________________________________________________________
- (void) reachabilityStatusChanged : (Reachability *) current
{
#pragma unused(current)
   
   if (internetReach && [internetReach currentReachabilityStatus] == NetworkStatus::notReachable) {
      if (currentConnection) {
         [currentConnection cancel];
         currentConnection = nil;
         
         isDownloading = NO;
         
         if (self.delegate && [self.delegate respondsToSelector : @selector(photoDownloader:didFailWithError:)])
            [self.delegate photoDownloader : self didFailWithError : nil];
      }
   }
}

//________________________________________________________________________________________
- (bool) hasConnection
{
   return internetReach && [internetReach currentReachabilityStatus] != NetworkStatus::notReachable;
}

#pragma mark - Object's lifetime management.

//________________________________________________________________________________________
- (id) init
{
   if (self = [super init]) {
      parser = [[CernMediaMARCParser alloc] init];
      parser.delegate = self;
      parser.resourceTypes = @[@"jpgA4", @"jpgA5", @"jpgIcon"];
      //
      //
      [[NSNotificationCenter defaultCenter] addObserver : self selector : @selector(reachabilityStatusChanged:) name : CernAPP::reachabilityChangedNotification object : nil];
      internetReach = [Reachability reachabilityForInternetConnection];
      [internetReach startNotifier];
   }

   return self;
}

//________________________________________________________________________________________
- (void) dealloc
{
   [self stop];
   [internetReach stopNotifier];
   [[NSNotificationCenter defaultCenter] removeObserver : self];
}

//________________________________________________________________________________________
- (void) stop
{
   if (currentConnection) {
      [currentConnection cancel];
      currentConnection = nil;
      thumbnailData = nil;
      photoSetToLoad = 0;
      imageToLoad = 0;
   }
   
   [parser stop];
   
   isDownloading = NO;
}

#pragma mark - Aux. methods.

//________________________________________________________________________________________
- (NSURL *) url
{
   return parser.url;
}

//________________________________________________________________________________________
- (void) setUrl : (NSURL *) url
{
   assert(url != nil && "setUrl:, parameter 'url' is nil");
   parser.url = url;
}

//________________________________________________________________________________________
- (void) parse
{
   isDownloading = YES;
   photoSets = [[NSMutableArray alloc] init];
   [parser parse];
}

//________________________________________________________________________________________
- (void) downloadNextThumbnail
{
   assert(isDownloading == YES && "downloadNextThumbnail, not downloading at the moment");
   
   assert(photoSetToLoad < photoSets.count && "downloadNextThumbnail, photoSetToLoad is out of bounds");
   PhotoSet * const currentSet = (PhotoSet *)photoSets[photoSetToLoad];
   
   assert(imageToLoad < [currentSet nImages] && "downloadNextThumbnail, imageToLoad is out of bounds");

   NSURL * const url = [currentSet getImageURLWithIndex : imageToLoad forType : @"jpgIcon"];
   thumbnailData = [[NSMutableData alloc] init];
   currentConnection = [NSURLConnection connectionWithRequest : [NSURLRequest requestWithURL : url] delegate : self];
   //ok, poehali.
}

#pragma mark CernMediaMARCParserDelegate methods

//________________________________________________________________________________________
- (void) parser : (CernMediaMARCParser *) aParser didParseRecord : (NSDictionary *) record
{
   assert(isDownloading == YES && "parser:didParseRecord:, not downloading at the moment");

   //Eamon:
   // "we will assume that each array in the dictionary has the same number of photo urls".
   
   //Me:
   // No, this assumption does not work :( some images can be omitted - for example, 'jpgIcon'.

   assert(aParser != nil && "parser:didParseRecord:, parameter 'aParser' is null");
   assert(record != nil && "parser:didParseRecord:, parameter 'record' is null");
   
   //Now, we do some magic to fix bad assumptions.

   NSDictionary * const resources = (NSDictionary *)record[@"resources"];
   assert(resources != nil && "parser:didParseRecord:, no object for the key 'resources' was found");
   
   const NSUInteger nPhotos = ((NSArray *)resources[aParser.resourceTypes[0]]).count;
   for (NSUInteger i = 1, e = aParser.resourceTypes.count; i < e; ++i) {
      NSArray * const typedData = (NSArray *)[resources objectForKey : [aParser.resourceTypes objectAtIndex : i]];
      if (typedData.count != nPhotos) {
         //I simply ignore this record - have no idea what to do with such a data.
         return;
      }
   }

   PhotoSet * const newSet = [[PhotoSet alloc] init];

   NSArray * const a4Data = (NSArray *)resources[@"jpgA4"];
   NSArray * const a5Data = (NSArray *)resources[@"jpgA5"];
   NSArray * const iconData = (NSArray *)resources[@"jpgIcon"];

   for (NSUInteger i = 0; i < nPhotos; i++) {
      NSDictionary * const newImageData = @{@"jpgA4" : a4Data[i], @"jpgA5" : a5Data[i], @"jpgIcon" : iconData[i]};
      [newSet addImageData:newImageData];
   }
   
   newSet.title = record[@"title"];
   
   [photoSets addObject : newSet];
}

//________________________________________________________________________________________
- (void) parserDidFinish : (CernMediaMARCParser *) aParser
{
   #pragma unused(aParser)

   //We start downloading images here.

   if (delegate && [delegate respondsToSelector : @selector(photoDownloaderDidFinish:)])
      [delegate photoDownloaderDidFinish : self];

   if (photoSets.count) {
      if (!self.hasConnection) {
         //We lost a connection during parsing??? :)
         if (self.delegate && [self.delegate respondsToSelector : @selector(photoDownloader:didFailWithError:)])
            [self.delegate photoDownloader : self didFailWithError : nil];
      } else {
         photoSetToLoad = 0;
         imageToLoad = 0;
         [self downloadNextThumbnail];
      }
   }
}

//________________________________________________________________________________________
- (void) parser : (CernMediaMARCParser *) aParser didFailWithError : (NSError *) error
{
#pragma unused(aParser)

   if (self.delegate && [self.delegate respondsToSelector : @selector(photoDownloader:didFailWithError:)])
      [self.delegate photoDownloader : self didFailWithError : error];
}

#pragma mark - NSURLConnectionDelegate

//________________________________________________________________________________________
- (void) connection : (NSURLConnection *) urlConnection didReceiveData : (NSData *) data
{
   assert(urlConnection != nil && "connection:didReceiveData:, parameter 'urlConnection' is nil");
   if (currentConnection != urlConnection) {
      NSLog(@"connection:didReceiveData:, called from a cancelled connection");
      return;
   }

   assert(isDownloading == YES && "connection:didReceiveData:, not downloading at the moment");
   assert(thumbnailData != nil && "connection:didReceiveData:, thumbnailData is nil");
   assert(data != nil && "connection:didReceiveData:, parameter 'data' is nil");

   [thumbnailData appendData : data];
}

//________________________________________________________________________________________
- (void) connection : (NSURLConnection *) urlConnection didFailWithError : (NSError *) error
{
#pragma unused(error)

   assert(urlConnection != nil && "connection:didFailWithError:, parameter 'urlConnection' is nil");

   if (currentConnection != urlConnection) {
      NSLog(@"connection:didFailWithError:, called from a cancelled connection");
      return;
   }

   assert(isDownloading == YES && "connection:didFailWithError:, not downloading at the moment");
   assert(photoSetToLoad < photoSets.count && "connection:didFailWithError:, photoSetToLoad is out of bounds");

   PhotoSet * const currentSet = photoSets[photoSetToLoad];

   if (imageToLoad + 1 == [currentSet nImages]) {
      imageToLoad = 0;
      
      if (photoSetToLoad + 1 == photoSets.count) {
         self.isDownloading = NO;
         
         if (self.delegate && [self.delegate respondsToSelector : @selector(photoDownloaderDidFinishLoadingThumbnails:)])
            [self.delegate photoDownloaderDidFinishLoadingThumbnails : self];
      } else {
         //Still continue.
         ++photoSetToLoad;
         [self downloadNextThumbnail];
      }
   } else {
      ++imageToLoad;
      [self downloadNextThumbnail];
   }
}

//________________________________________________________________________________________
- (void) connectionDidFinishLoading : (NSURLConnection *) urlConnection
{
   assert(urlConnection != nil && "connectionDidFinishLoading:, parameter 'urlConnection' is nil");
   if (currentConnection != urlConnection) {
      NSLog(@"connectionDidFinishLoading, called from a cancelled connection");
      return;
   }

   assert(isDownloading == YES && "connectionDidFinishLoading:, not downloading at the moment");
   assert(thumbnailData != nil && "connectionDidFinishLoading:, thumbnailData is nil");

   assert(photoSetToLoad < photoSets.count && "connectionDidFinishLoading:, photoSetToLoad is out of bounds");
   PhotoSet * const currentSet = photoSets[photoSetToLoad];
   assert(imageToLoad < [currentSet nImages] && "connectionDidFinishLoading:, imageToLoad is out of bounds");
   
   if (thumbnailData.length) {
      if (UIImage *newImage = [UIImage imageWithData : thumbnailData]) {
         [currentSet setThumbnailImage:newImage withIndex:imageToLoad];

         if (delegate && [delegate respondsToSelector : @selector(photoDownloader:didDownloadThumbnail:forSet:)])
            [delegate photoDownloader : self didDownloadThumbnail : imageToLoad forSet : photoSetToLoad];
      }
   }
   
   if (imageToLoad + 1 < [currentSet nImages]) {
      ++imageToLoad;
      [self downloadNextThumbnail];
   } else {
      imageToLoad = 0;
      currentConnection = nil;
      thumbnailData = nil;
      
      if (photoSetToLoad + 1 < photoSets.count) {
         ++photoSetToLoad;
         [self downloadNextThumbnail];
      } else {
         photoSetToLoad = 0;
         self.isDownloading = NO;

         if (self.delegate && [self.delegate respondsToSelector : @selector(photoDownloaderDidFinishLoadingThumbnails:)])
            [self.delegate photoDownloaderDidFinishLoadingThumbnails : self];      
      }
   }
}

//________________________________________________________________________________________
- (void) compactData
{
   for (PhotoSet * set in photoSets)
      [set compactPhotoSet];
   
   NSPredicate * const predicate = [NSPredicate predicateWithBlock : ^ BOOL (id evaluatedObject, NSDictionary *bindings) {
      return [(PhotoSet *)evaluatedObject nImages] != 0;
   }];

   [photoSets filterUsingPredicate : predicate];
}

@end
