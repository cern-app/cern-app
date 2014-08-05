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

//________________________________________________________________________________________
NSString *LargeImageType()
{
   /*if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
      return @"jpgA4";
   
   return @"jpgA5";*/
   return CernAPP::iPadImageUrl;
}

//________________________________________________________________________________________
NSString *LargeIconImageType()
{
   return @"icon-640";
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
- (id) initWithXMLData : (NSData *) xmlData datafieldTags : (NSSet *) tags
       subfieldCodes : (NSSet *) codes
{
   assert(xmlData != nil &&
          "initWithXMLData:datafieldTags:subfieldCodes:, parameter 'xmlData' is nil");
   assert(xmlData.length != 0 &&
          "initWithXMLData:datafieldTags:subfieldCodes:, xmlData is empty");
   assert(tags != nil &&
          "initWithXMLData:datafieldTags:subfieldCodes:, parameter 'tags' is nil");
   assert(codes != nil &&
          "initWithXMLData:datafieldTags:subfieldCodes:, parameter 'codes' is nil");

   self = [super initWithXMLData : xmlData datafieldTags : tags subfieldCodes : codes];

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

   for (NSDictionary * const datafield in recordData) {
      assert(datafield[@"tag"] != nil &&
             "processDatafields, unknown datafield (no tag found)");
      NSString * const tag = (NSString *)datafield[@"tag"];
      if ([tag isEqualToString : CernAPP::CDStagMARC])
         [self processMARCDatafield:datafield];
      else if ([tag isEqualToString : CernAPP::CDStagDate])
         [self processDateDatafield : datafield];
      else if ([tag isEqualToString : CernAPP::CDStagTitle] || [tag isEqualToString : CernAPP::CDStagTitleAlt])
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
   
   NSCharacterSet * const charSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];

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
         thumbnailUrl = CernAPP::Details::GetThumbnailURLString(imageUrl);
      //Uff.
      if (!thumbnailUrl)
         thumbnailUrl = imageUrl;

      

      [newAlbum addImageData : @{CernAPP::iPadImageUrl : [NSURL URLWithString : [[imageUrl stringByTrimmingCharactersInSet : charSet]
                                                                                 stringByAddingPercentEscapesUsingEncoding : NSUTF8StringEncoding]],
                                 CernAPP::thumbnailImageUrl : [NSURL URLWithString : [[thumbnailUrl stringByTrimmingCharactersInSet : charSet]
                                                                                      stringByAddingPercentEscapesUsingEncoding : NSUTF8StringEncoding]]}];
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
         if ([contentType isEqualToString : CernAPP::LargeImageType()])
            [imageUrls addObject : url];
         else if ([contentType isEqualToString : CernAPP::LargeIconImageType()]) {//It's a large size image.
            const NSRange epsExt = [url rangeOfString : @".eps?"];//UGLY hack again :(((
            //I have a bad feeling, UIImage doesn't give a f..k about eps.
            if (epsExt.location == NSNotFound)
               [imageUrls addObject : url];
         } else if ([contentType isEqualToString : @"icon"] || [contentType isEqualToString : @"icon-180"] || [contentType isEqualToString : @"jpgIcon"])
            [thumbnailUrls addObject : url];
         //ignore others.
      } else {
         //[imageUrls addObject : url];
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
   assert(datafield[@"tag"] != nil &&
          ([(NSString *)datafield[@"tag"] isEqualToString : CernAPP::CDStagTitle] ||
           [(NSString *)datafield[@"tag"] isEqualToString : CernAPP::CDStagTitleAlt]) &&
          "processTitleDatafield:, invalid datafield's tag");
   assert(newAlbum != nil && "processTitleDatafield:, newAlbum is nil");
   
   if (NSString * const titleString = (NSString *)datafield[CernAPP::CDScodeTitle]) {
      if (titleString.length && !newAlbum.title)
         newAlbum.title = titleString;
   }
}

@end
