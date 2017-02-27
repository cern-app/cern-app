//
//  NSDate+LastOccurrenceOfWeekday.m
//  CERN App
//
//  Created by Eamon Ford on 7/30/12.
//  Copyright (c) 2012 CERN. All rights reserved.
//

#import "NSDate+LastOccurrenceOfWeekday.h"

@implementation NSDate (LastOccurrenceOfWeekday)

- (NSDate *)nextOccurrenceOfWeekday : (int) targetWeekday
{
   NSCalendar *calendar = [NSCalendar currentCalendar];
   //calendar.timeZone = [NSTimeZone timeZoneWithName:@"GMT"];
   NSDateComponents *components = [calendar components : NSCalendarUnitWeekday fromDate : self];

   
   const long startingWeekday = components.weekday;
   const int daysTillTarget = (targetWeekday - startingWeekday + 7) % 7;

   return [self dateByAddingTimeInterval : 60 * 60 * 24 * daysTillTarget];
}

- (NSDate *)midnight
{
   NSDateComponents *components = [[NSCalendar currentCalendar] components : NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay fromDate:self];
   components.hour = 0;
   components.minute = 0;
   components.second = 0;
   //components.timeZone = [NSTimeZone timeZoneWithName:@"GMT"];
    
    return [[NSCalendar currentCalendar] dateFromComponents:components];
}

@end
