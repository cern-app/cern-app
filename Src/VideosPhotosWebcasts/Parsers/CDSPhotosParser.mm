//
//  CDSPhotosParser.m
//  CERN
//
//  Created by Timur Pocheptsov on 10/3/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import "NSDateFormatter+DateFromStringOfUnknownFormat.h"
#import "CDSPhotosParser.h"
#import "CDSPhotoAlbum.h"
#import "TwitterAPI.h"

namespace CernAPP {

NSString * const CDStagMARC = @"856";
NSString * const CDStagTitle = @"245";
NSString * const CDStagDate = @"269";

NSString * const CDScodeURL = @"u";
NSString * const CDScodeContent = @"x";
NSString * const CDScodeDate = @"c";
NSString * const CDScodeTitle = @"a";

//________________________________________________________________________________________
NSString *LargeImageType()
{
   /*if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
      return @"jpgA4";
   
   return @"jpgA5";*/
   return CernAPP::iPadImage;
}

}

@implementation CDSPhotosParserOperation {
   NSMutableArray *photoAlbums;
   
   NSMutableArray *imageUrls;
   NSMutableArray *thumbnailUrls;
   NSMutableArray *photos;
   CDSPhotoAlbum *newAlbum;
   
   NSDateFormatter *dateFormatter;
}

//________________________________________________________________________________________
- (id) initWithURLString : (NSString *) urlString datafieldTags : (NSSet *) tags
       subfieldCodes : (NSSet *) codes
{
   assert(urlString != nil &&
          "initWithURLString:datafieldTags:subfieldCodes:, parameter 'urlString' is nil");
   assert(tags != nil &&
          "initWithURLString:datafieldTags:subfieldCodes:, parameter 'tags' is nil");
   assert(codes != nil &&
          "initWithURLString:datafieldTags:subfieldCodes:, parameter 'codes' is nil");

   self = [super initWithURLString : urlString datafieldTags : tags subfieldCodes : codes];
   if (self) {
      photoAlbums = [[NSMutableArray alloc] init];
      dateFormatter = [[NSDateFormatter alloc] init];
   }

   return self;
}

#pragma mark - CDSParserOperationDelegate.

//________________________________________________________________________________________
- (void) parser : (CDSXMLParser *) aParser didParseRecord : (NSArray *) recordData
{
#pragma unused(aParser)
   assert(recordData != nil && "parser:didParseRecord:, parameter 'recordData' is nil");

   if (self.isCancelled || !recordData.count)
      return;

   //1. Find all images in a record.
   [self processDatafields : recordData];
   //2. Using image urls, find the corresponding thumbnails.
   if (imageUrls) {
      [self addPhotoalbum];
      assert(newAlbum != nil && "parser:didParseRecord:, newAlbum is nil");
      if (newAlbum.nImages)
         [photoAlbums addObject : newAlbum];
   }
}

//________________________________________________________________________________________
- (void) parserDidFinish : (CDSXMLParser *) parser
{
#pragma unused(parser)

   if (self.isCancelled)
      return;

   assert(photoAlbums != nil && "parserDidFinish:, photoAlbums is nil");//it can be empty, but not nil!
   [self performSelectorOnMainThread : @selector(informDelegateAboutCompletionWithItems:)
         withObject : photoAlbums waitUntilDone : NO];
}

#pragma mark - Methods to intepret XML parser's output.

//________________________________________________________________________________________
- (void) processDatafields : (NSArray *) recordData
{
   assert(recordData && recordData.count &&
          "processDatafields:, parameter 'recordData' is either nil or an empty array");

   imageUrls = [[NSMutableArray alloc] init];
   thumbnailUrls = [[NSMutableArray alloc] init];
   newAlbum = [[CDSPhotoAlbum alloc] init];

   for (NSObject *baseObj in recordData) {
      assert([baseObj isKindOfClass : [NSDictionary class]] &&
             "processDatafields:, unknown object found in a record");
      NSDictionary * const datafield = (NSDictionary *)baseObj;
      assert(datafield[@"tag"] != nil &&
             "processDatafields, unknown datafield (no tag found)");
      NSString * const tag = (NSString *)datafield[@"tag"];
      if ([tag isEqualToString : CernAPP::CDStagMARC])
         [self processMARCDatafield:datafield];
      else if ([tag isEqualToString : CernAPP::CDStagDate])
         [self processDateDatafield : datafield];
      else if ([tag isEqualToString : CernAPP::CDStagTitle])
         [self processTitleDatafield : datafield];
   }
}

//________________________________________________________________________________________
- (void) addPhotoalbum
{
   assert(imageUrls != nil && "addPhotoalbum, imageUrls is nil");
   assert(thumbnailUrls != nil && "addPhotoalbum, thumbnailUrls is nil");
   assert(newAlbum != nil && "addPhotoalbum, newAlbum is nil");
   
   if (!imageUrls.count)
      return;

   for (NSString * imageUrl in imageUrls) {
      //This "algorithm" is terribly ineffecient, but ... not too much I can do with our input
      //and with Apple's "brilliant" frameworks.
      
      //Also, nobody gives us any guarantee about file names and extensioins.
      NSRange extRange = [imageUrl rangeOfString : @"-A4-at-144-dpi" options : NSBackwardsSearch];
      if (extRange.location == NSNotFound)
         extRange = [imageUrl rangeOfString : @"." options : NSBackwardsSearch];

      NSString *urlPattern = imageUrl;
      if (extRange.location != NSNotFound && extRange.location > 0)
         urlPattern = [imageUrl substringWithRange:NSMakeRange(0, extRange.location)];

      NSString *thumbnailUrl = nil;
      for (NSString * urlToTest in thumbnailUrls) {
         if ([urlToTest rangeOfString:urlPattern].location != NSNotFound) {
            thumbnailUrl = urlToTest;
            break;
         }
      }
      
      if (!thumbnailUrl)//The last try.
         thumbnailUrl = CernAPP::Details::GetThumbnailURL(imageUrl);
      //Uff.
      if (!thumbnailUrl)
         thumbnailUrl = imageUrl;

      [newAlbum addImageData : @{CernAPP::iPadImage : imageUrl, CernAPP::thumbnailImage : thumbnailUrl}];
   }
   
   imageUrls = nil;
   thumbnailUrls = nil;
}

//________________________________________________________________________________________
- (void) processMARCDatafield : (NSDictionary *) datafield
{
   assert(datafield != nil && "processMARCDatafield:, parameter 'datafield' is nil");
   assert(datafield[@"tag"] != nil && [(NSString *)datafield[@"tag"] isEqualToString : CernAPP::CDStagMARC] &&
          "processMARCDatafield:, datafield has a wrong type");
   assert(imageUrls != nil && "processMARCDatafield:, imageUrls is nil");
   assert(thumbnailUrls != nil && "processMARCDatafield, thumbnailUrls is nil");

   if (NSString * const url = (NSString *)datafield[CernAPP::CDScodeURL]) {
      if (NSString * const contentType = (NSString *)datafield[CernAPP::CDScodeContent]) {
         if ([contentType isEqualToString : CernAPP::LargeImageType()])//It's a large size image.
            [imageUrls addObject : url];
         else if ([contentType isEqualToString : @"icon"] || [contentType isEqualToString : @"icon-180"] || [contentType isEqualToString : @"jpgIcon"])
            [thumbnailUrls addObject : url];
         //ignore others.
      } else {
         [imageUrls addObject : url];
      }
   }//Else we completely skip this datafield.
}

//________________________________________________________________________________________
- (void) processDateDatafield : (NSDictionary *) datafield
{
   assert(datafield != nil && "processDateDatafield:, parameter 'datafield' is nil");
   assert(datafield[@"tag"] != nil && [datafield[@"tag"] isEqualToString : CernAPP::CDStagDate] &&
          "processDateDatafield: invalid datafield's tag");

   if (NSString * const dateString = (NSString *)datafield[CernAPP::CDScodeDate]) {
      NSDate * const date = [dateFormatter dateFromStringOfUnknownFormat : dateString];
      if (date);//Not using the date at the moment.
   }
}

//________________________________________________________________________________________
- (void) processTitleDatafield : (NSDictionary *) datafield
{
   assert(datafield != nil && "processTitleDatafield:, parameter 'datafield' is nil");
   assert(datafield[@"tag"] != nil && [(NSString *)datafield[@"tag"] isEqualToString : CernAPP::CDStagTitle] &&
          "processTitleDatafield:, invalid datafield's tag");
   assert(newAlbum != nil && "processTitleDatafield:, newAlbum is nil");
   
   if (NSString * const titleString = (NSString *)datafield[CernAPP::CDScodeTitle]) {
      if (titleString.length)
         newAlbum.title = titleString;
   }
}

@end
