//
//  NSDateFormatter+DateFromStringOfUnknownStyle.m
//  CERN App
//
//  Created by Eamon Ford on 7/6/12.
//  Copyright (c) 2012 CERN. All rights reserved.
//

//Fixed by Timur Pocheptsov.

#import "NSDateFormatter+DateFromStringOfUnknownFormat.h"

@implementation NSDateFormatter (DateFromStringOfUnknownFormat)

//________________________________________________________________________________________
- (NSDate *) dateFromStringOfUnknownFormat : (NSString *) string
{
   //These properties will be modified, save the current values
   //to restore later.
   NSLocale * const currentLocale = self.locale;
   const NSDateFormatterStyle currentDateStyle = self.dateStyle;
   const BOOL isLenient = self.isLenient;
   const NSDateFormatterStyle currentTimeStyle = self.timeStyle;

   self.timeStyle = NSDateFormatterNoStyle;
   [self setLenient : YES];

   NSDate *date = nil;
   
   NSArray * const allLocales = [NSLocale availableLocaleIdentifiers];
   for (NSString * localeName in allLocales) {
      self.locale = [[NSLocale alloc] initWithLocaleIdentifier : localeName];

      self.dateStyle = NSDateFormatterShortStyle;
      date = [self dateFromString : string];
      if (date)
         break;
      self.dateStyle = NSDateFormatterMediumStyle;
      date = [self dateFromString : string];
      if (date)
         break;
      self.dateStyle = NSDateFormatterLongStyle;
      date = [self dateFromString : string];
      if (date)
         break;
      self.dateStyle = NSDateFormatterFullStyle;
      date = [self dateFromString : string];
      if (date)
         break;
   }
   
   //Reset properties.
   self.locale = currentLocale;
   self.dateStyle = currentDateStyle;
   [self setLenient : isLenient];
   self.timeStyle = currentTimeStyle;
   
   return date;
}

@end
