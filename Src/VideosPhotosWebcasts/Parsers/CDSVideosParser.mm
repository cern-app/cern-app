//
//  CDSVideosParser.m
//  CERN
//
//  Created by Timur Pocheptsov on 10/4/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <cassert>

#import "NSDateFormatter+DateFromStringOfUnknownFormat.h"
#import "CDSVideosParser.h"

namespace CernAPP {

NSString * const CDSvideoURL = @"videoURL";
NSString * const CDSvideoThubmnailURL = @"videoThumbnailURL";

}

@implementation CDSVideosParserOperation {
   NSMutableArray *videosMetadata;
   NSMutableDictionary *video;
   NSUInteger frame;

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
      videosMetadata = [[NSMutableArray alloc] init];
      video = nil;
      frame = 0;
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

   if (recordData.count) {
      video = [[NSMutableDictionary alloc] init];
      frame = 0;
      [self processRecord : recordData];
      if (video.count && video[CernAPP::CDSvideoURL])
         [videosMetadata addObject : video];
   }
}

//________________________________________________________________________________________
- (void) parserDidFinish : (CDSXMLParser *) parser
{
#pragma unused(parser)

   if (!self.isCancelled) {
      [self performSelectorOnMainThread : @selector(informDelegateAboutCompletionWithItems:)
            withObject : videosMetadata waitUntilDone : NO];
   }
}

#pragma mark - Methods to process datafields and subfields.

//________________________________________________________________________________________
- (void) processRecord : (NSArray *) recordData
{
   assert(recordData != nil && "processRecord: parameter 'recordData' is nil");

   if (!recordData.count)
      return;

   for (NSDictionary *datafield in recordData) {
      assert(datafield[@"tag"] != nil && "processRecord:, unknown datafield (no tag found)");
      NSString * const tag = (NSString *)datafield[@"tag"];
      if ([tag isEqualToString : CernAPP::CDStagTitle] || [tag isEqualToString : CernAPP::CDStagTitleAlt])
         [self processTitleDatafield : datafield];
      else if ([tag isEqualToString : CernAPP::CDStagDate])
         [self processDateDatafield : datafield];
      else if ([tag isEqualToString : CernAPP::CDStagMARC])
         [self processMARCDatafield : datafield];
   }
}

//________________________________________________________________________________________
- (void) processTitleDatafield : (NSDictionary *) datafield
{
   assert(datafield != nil && "processTitleDatafield:, parameter 'datafield' is nil");
   assert(datafield[@"tag"] != nil && "processTitleDatafield:, unknown datafiled (no tag found)");
   assert(([(NSString *)datafield[@"tag"] isEqualToString : CernAPP::CDStagTitle] ||
           [(NSString *)datafield[@"tag"] isEqualToString : CernAPP::CDStagTitleAlt])
          && "processTitleDatafield:, invalid datafield tag");
   assert(video != nil && "processTitleDatafield:, video is nil");
   
   if (!video[@"title"]) {
      if (NSString * const title = datafield[CernAPP::CDScodeTitle]) {
         [video setObject : title forKey : CernAPP::CDScodeTitle];
      }
   }
}

//________________________________________________________________________________________
- (void) processDateDatafield : (NSDictionary *) datafield
{
   assert(datafield != nil && "processDateDatafield:, parameter 'datafield' is nil");
   assert(datafield[@"tag"] != nil && [(NSString *)datafield[@"tag"] isEqualToString:CernAPP::CDStagDate] &&
          "processDateDatafield:, datafield tag not found or is invalid");
   assert(video != nil && "processDateDatafield:, video is nil");
   
   //Process the date.
   if (NSString * const dateString = (NSString *)datafield[CernAPP::CDScodeDate]) {
      if (NSDate * const date = [dateFormatter dateFromStringOfUnknownFormat : dateString]) {
         if (!video[CernAPP::CDScodeDate])
            [video setObject : date forKey : CernAPP::CDScodeDate];
      }
   }
}

//________________________________________________________________________________________
- (void) processMARCDatafield : (NSDictionary *) datafield
{
   assert(datafield != nil && "processMARCDatafield:, parameter 'datafield' is nil");
   assert(datafield[@"tag"] != nil && "processMARCDatafield:, uknown datafied (no tag found)");
   assert([(NSString *)datafield[@"tag"] isEqualToString : CernAPP::CDStagMARC] &&
          "processMARCDatafield:, datafield has a wrong tag");

   if (NSString * const urlString = (NSString *)datafield[CernAPP::CDScodeURL]) {
      if (NSString * const content = (NSString *)datafield[CernAPP::CDScodeContent]) {
         if ([content isEqualToString : @"jpgposterframe"]) {
            //Thubmnail for our video.
            if (frame < 3) {//Usually, the first frame is quite bad, the next one (if exists)
                            //is at 10% of video playback and is much better.
               if (NSURL * const thumbnailURL = [NSURL URLWithString : urlString]) {
                  ++frame;
                  [video setObject:thumbnailURL forKey : CernAPP::CDSvideoThubmnailURL];
               }
            }
         } else if ([content isEqualToString : @"mp40600"]) {
            if (NSURL * const videoURL = [NSURL URLWithString : urlString])
               [video setObject : videoURL forKey : CernAPP::CDSvideoURL];
         }
      }
   }
}

@end
