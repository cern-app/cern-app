//
//  CDSPhotosParser.m
//  CERN
//
//  Created by Timur Pocheptsov on 10/3/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import "CDSPhotosParser.h"
#import "CDSPhotoAlbum.h"

@implementation CDSPhotosParserOperation {
   NSMutableArray *photoAlbums;
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
   }
   
   return self;
}

//________________________________________________________________________________________
- (void) parser : (CDSXMLParser *) aParser didParseRecord : (NSArray *) recordData
{
#pragma unused(aParser)

   if (self.isCancelled)
      return;
   
   //TODO: create a CDSPhotoAlbum from this record.
   NSLog(@"got a record:\n%@", recordData);
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

@end
