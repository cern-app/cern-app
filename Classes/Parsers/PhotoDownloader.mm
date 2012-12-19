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

@implementation PhotoDownloader {
   CernMediaMARCParser *parser;
   NSMutableData *thumbnailData;
   NSURLConnection *currentConnection;
   NSUInteger imageToLoad;
}

@synthesize urls, thumbnails, delegate, isDownloading;

//________________________________________________________________________________________
- (id) init
{
   if (self = [super init]) {
      parser = [[CernMediaMARCParser alloc] init];
      parser.delegate = self;
      parser.resourceTypes = @[@"jpgA4", @"jpgA5", @"jpgIcon"];
   }

   return self;
}

//________________________________________________________________________________________
- (NSURL *) url
{
   return parser.url;
}

//________________________________________________________________________________________
- (void) setUrl : (NSURL *) url;
{
   parser.url = url;
}

//________________________________________________________________________________________
- (void) parse
{
   isDownloading = YES;
   urls = [[NSMutableArray alloc] init];
   thumbnails = [NSMutableDictionary dictionary];
   [parser parse];
}

#pragma mark CernMediaMARCParserDelegate methods

//________________________________________________________________________________________
- (void) parser : (CernMediaMARCParser *) aParser didParseRecord : (NSDictionary *) record
{
   //From Eamon:
   // "we will assume that each array in the dictionary has the same number of photo urls".
   
   //From me:
   // No, this assumption does not work :( some images can be omitted - for example, 'jpgIcon'.

   assert(aParser != nil && "parser:didParseRecord:, parameter 'aParser' is null");
   assert(record != nil && "parser:didParseRecord:, parameter 'record' is null");
   
   //Now, we do some magic to fix bad assumptions.

   NSDictionary * const resources = (NSDictionary *)[record objectForKey : @"resources"];
   assert(resources != nil && "parser:didParseRecord:, no object for the key 'resources' was found");
   
   const NSUInteger nPhotos = ((NSArray *)[resources objectForKey : [aParser.resourceTypes objectAtIndex : 0]]).count;
   for (NSUInteger i = 1, e = aParser.resourceTypes.count; i < e; ++i) {
      NSArray * const typedData = (NSArray *)[resources objectForKey : [aParser.resourceTypes objectAtIndex : i]];
      if (typedData.count != nPhotos) {
         //I simply ignore this record - have no idea what to do with such a data.
         return;
      }
   }

   for (NSUInteger i = 0; i < nPhotos; i++) {
      NSMutableDictionary * const photo = [NSMutableDictionary dictionary];
      NSArray * const resourceTypes = parser.resourceTypes;
      
      const NSUInteger numResourceTypes = resourceTypes.count;
      for (NSUInteger j = 0; j < numResourceTypes; j++) {
         NSString * const currentResourceType = [resourceTypes objectAtIndex : j];
         NSURL * const url = [[resources objectForKey : currentResourceType] objectAtIndex : i];
         [photo setObject : url forKey : currentResourceType];
      }
   
      [self.urls addObject : photo];
   }
}

//________________________________________________________________________________________
- (void) downloadNextThumbnail
{
   assert(isDownloading == YES && "downloadNextThumbnail, not downloading at the moment");
   assert(imageToLoad < [urls count] && "downloadNextThumbnail, imageToLoad is out of bounds");

   NSDictionary * const photoData = (NSDictionary *)[urls objectAtIndex : imageToLoad];
   if (id urlBase = [photoData objectForKey : @"jpgIcon"]) {
      assert([urlBase isKindOfClass:[NSURL class]] &&
             "downloadNextThumbnail, photo data must be a dictionary");
      
      thumbnailData = [[NSMutableData alloc] init];
      currentConnection = [NSURLConnection connectionWithRequest:[NSURLRequest requestWithURL:(NSURL *)urlBase] delegate : self];
      //ok, poehali.
   }
}

//________________________________________________________________________________________
- (void) parserDidFinish : (CernMediaMARCParser *) parser
{
   //We start downloading images here.

   if (delegate && [delegate respondsToSelector : @selector(photoDownloaderDidFinish:)])
      [delegate photoDownloaderDidFinish : self];

   if (urls.count) {
      imageToLoad = 0;
      [self downloadNextThumbnail];
   }
}

//________________________________________________________________________________________
- (void) parser : (CernMediaMARCParser *) parser didFailWithError : (NSError *) error
{
   if (self.delegate && [self.delegate respondsToSelector : @selector(photoDownloader : didFailWithError:)])
      [self.delegate photoDownloader : self didFailWithError : error];
}

#pragma mark - NSURLConnectionDelegate

//________________________________________________________________________________________
- (void) connection : (NSURLConnection *) connection didReceiveData : (NSData *) data
{
   assert(isDownloading == YES && "connection:didReceiveData:, not downloading at the moment");
   assert(thumbnailData != nil && "connection:didReceiveData:, thumbnailData is nil");
   assert(data != nil && "connection:didReceiveData:, parameter 'data' is nil");

   [thumbnailData appendData : data];
}

//________________________________________________________________________________________
- (void) connection : (NSURLConnection *) connection didFailWithError : (NSError *) error
{
   assert(isDownloading == YES && "connection:didFailWithError:, not downloading at the moment");

   if (imageToLoad + 1 == urls.count) {
      imageToLoad = 0;
      isDownloading = NO;
   } else {
      ++imageToLoad;
      [self downloadNextThumbnail];
   }
}

//________________________________________________________________________________________
- (void) connectionDidFinishLoading : (NSURLConnection *) connection
{
   assert(isDownloading == YES && "connectionDidFinishLoading:, not downloading at the moment");
   assert(thumbnailData != nil && "connectionDidFinishLoading:, thumbnailData is nil");

   #pragma unused(connection)
   
   if (thumbnailData.length) {
      if (UIImage *newImage = [UIImage imageWithData : thumbnailData]) {
         [self.thumbnails setObject : newImage forKey : [NSNumber numberWithInt : imageToLoad]];

         if (delegate && [delegate respondsToSelector : @selector(photoDownloader:didDownloadThumbnailForIndex:)])
            [delegate photoDownloader : self didDownloadThumbnailForIndex : imageToLoad];
      }
   }
   
   if (imageToLoad + 1 < urls.count) {
      ++imageToLoad;
      [self downloadNextThumbnail];
   } else {
      isDownloading = NO;
      currentConnection = nil;
      thumbnailData = nil;
      imageToLoad = 0;
   }
}

@end
