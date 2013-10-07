//
//  CDSPhotosParser.h
//  CERN
//
//  Created by Timur Pocheptsov on 10/3/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "CDSParser.h"

//This is the parser for CERN MediaArchive photos' xml.
//CDSXMLParser creates Obj-C data structures from XML
//and CDSPhotosParserOperation creates photo collection objects.



@interface CDSPhotosParserOperation : CDSParserOperation

- (id) initWithXMLData : (NSData *) xmlData datafieldTags : (NSSet *) tags
       subfieldCodes : (NSSet *) codes;

@end
