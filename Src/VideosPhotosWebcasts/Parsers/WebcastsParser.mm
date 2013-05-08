//
//  WebcastsParser.m
//  CERN App
//
//  Created by Eamon Ford on 8/16/12.
//  Copyright (c) 2012 CERN. All rights reserved.
//

#include <cassert>

#import "WebcastsParser.h"

NSString * const webcastURL = @"http://webcast.web.cern.ch/webcast/";

@implementation WebcastsParser {
   NSString *htmlString;
   NSMutableData *asyncData;
   NSUInteger numParsersLoading;
   
   NSURLConnection *currentConnection;
}

@synthesize recentWebcasts, upcomingWebcasts;
@synthesize delegate, pendingHTMLStringLoad, pendingRecentWebcastsParse, pendingUpcomingWebcastsParse;

//________________________________________________________________________________________
- (id) init
{
   return self = [super init];
}

//________________________________________________________________________________________
- (void) loadHTMLString
{
   if (!pendingHTMLStringLoad) {
      pendingHTMLStringLoad = YES;
      asyncData = [[NSMutableData alloc] init];
      self.recentWebcasts = [[NSMutableArray alloc] init];
      self.upcomingWebcasts = [[NSMutableArray alloc] init];
      NSURLRequest *request = [NSURLRequest requestWithURL : [NSURL URLWithString : webcastURL]];
      currentConnection = [NSURLConnection connectionWithRequest : request delegate : self];
   }
}

//________________________________________________________________________________________
- (void) parseRecentWebcasts
{
   if (!htmlString) {
      pendingRecentWebcastsParse = YES;
      [self loadHTMLString];
      return;
   }

   NSScanner *scanner = [NSScanner scannerWithString:htmlString];
   numParsersLoading = 0;
   [recentWebcasts removeAllObjects];
   while ([scanner scanUpToString : @"<div class=\"recentEvents\"" intoString : nil]) {
      NSString * const beginningOfLink = @"<a href=\"https://cdsweb.cern.ch/record/";
      if ([scanner scanUpToString : beginningOfLink intoString : nil]) {
         [scanner scanString : beginningOfLink intoString : nil];
         NSString *webcastID = @"";
         [scanner scanUpToString : @"\"" intoString : &webcastID];
         NSString * const marcURLString = [NSString stringWithFormat : @"https://cdsweb.cern.ch/record/%@/export/xm?ln=en",
                                           webcastID];
         numParsersLoading++;
         CernMediaMARCParser * const parser = [[CernMediaMARCParser alloc] init];
         parser.delegate = self;
         parser.url = [NSURL URLWithString : marcURLString];
         parser.resourceTypes = @[@"mp40600", @"mp4mobile", @"jpgposterframe", @"jpgthumbnail", @"pngthumbnail"];
         [parser parse];
      }
   }

   pendingRecentWebcastsParse = NO;
}

//________________________________________________________________________________________
- (void) parseUpcomingWebcasts
{
   if (!htmlString) {
      pendingUpcomingWebcastsParse = YES;
      [self loadHTMLString];
      return;
   }
   
   NSScanner * const scanner = [NSScanner scannerWithString : htmlString];
   [upcomingWebcasts removeAllObjects];
   while ([scanner scanUpToString : @"<div class=\"upcomEvents timezoneChange\"" intoString : nil]) {
      NSMutableDictionary * const webcast = [NSMutableDictionary dictionary];
      // Extract the image URL
      if ([scanner scanUpToString : @"<img class=\"upcomImg\" src=\"" intoString : nil]) {
         [scanner scanString : @"<img class=\"upcomImg\" src=\"" intoString : NULL];
         NSString *imageURL = nil;
         [scanner scanUpToString : @"\"" intoString : &imageURL];
         if (imageURL)
            [webcast setValue : [NSURL URLWithString : imageURL] forKey : @"thumbnailURL"];
      }
      
      // Extract the webcast title
      if ([scanner scanUpToString : @"<div class=\"upcomEventTitle\" title=\"" intoString : nil]) {
         [scanner scanString : @"<div class=\"upcomEventTitle\" title=\"" intoString : nil];
         NSString *title = nil;
         [scanner scanUpToString : @"\"" intoString : &title];
         if (title)
            [webcast setValue : title forKey : @"title"];
      }

      // Extract the webcast description
      if ([scanner scanUpToString : @"<div class=\"upcomEventDesc\" title=\"" intoString : nil]) {
         [scanner scanString : @"<div class=\"upcomEventDesc\" title=\"" intoString : nil];
         NSString *description = nil;
         [scanner scanUpToString : @"\"" intoString : &description];
         if (description)
            [webcast setValue : description forKey : @"description"];
      }
   
      // Extract the date
      if ([scanner scanUpToString : @"<p class=\"changeable_date_time\">" intoString : nil]) {
         [scanner scanString : @"<p class=\"changeable_date_time\">" intoString : nil];
         NSString *dateString = nil;
         [scanner scanUpToString : @"</p>" intoString : &dateString];
         NSTimeZone *timeZone = nil;
         // Extract the time zone
         if ([scanner scanUpToString : @"<p class=\"dynamic_timezone_label\">" intoString : nil]) {
            [scanner scanString:@"<p class=\"dynamic_timezone_label\">" intoString:NULL];
            NSString *timeZoneString = nil;
            [scanner scanUpToString : @"</p>" intoString : &timeZoneString];
            if (timeZoneString)
               timeZone = [NSTimeZone timeZoneWithName : timeZoneString];
         }
         
         NSDateFormatter * const dateFormatter = [[NSDateFormatter alloc] init];
         if (timeZone)
            dateFormatter.timeZone = timeZone;
         
         dateFormatter.dateFormat = @"MMMM d, yyyy h:mm a";
         NSDate *date  = nil;
         if (dateString)
            date = [dateFormatter dateFromString : dateString];
         if (!date)
            date = [NSDate date];
         [webcast setValue : date forKey : @"date"];
      }
      
      
      if (webcast.count)
         [upcomingWebcasts addObject : webcast];

      // Now sort the webcasts in order by date
      NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey : @"date" ascending : YES];
      upcomingWebcasts = [[upcomingWebcasts sortedArrayUsingDescriptors : @[sortDescriptor]] mutableCopy];

      if (delegate && [delegate respondsToSelector : @selector(webcastsParser:didParseUpcomingWebcast:)])
         [delegate webcastsParser : self didParseUpcomingWebcast : webcast];
   }
   
   pendingUpcomingWebcastsParse = NO;
    
   if (delegate && [delegate respondsToSelector : @selector(webcastsParserDidFinishParsingUpcomingWebcasts:)])
      [delegate webcastsParserDidFinishParsingUpcomingWebcasts : self];
}

#pragma mark NSURLConnectionDelegate methods

//________________________________________________________________________________________
- (void) connection : (NSURLConnection *) connection didReceiveData : (NSData *) data
{
#pragma unused(connection)
   assert(asyncData != nil && "connection:didReceiveData:, asyncData is nil");
   assert(data != nil && "connection:didReceiveData:, parameter 'data' is nil");

   [asyncData appendData:data];
}

//________________________________________________________________________________________
- (void) connectionDidFinishLoading : (NSURLConnection *) connection
{
#pragma unused(connection)

   if (asyncData.length) {
      htmlString = [[NSString alloc] initWithData : asyncData encoding : NSUTF8StringEncoding];
      pendingHTMLStringLoad = NO;
    
      if (pendingRecentWebcastsParse)
         [self parseRecentWebcasts];
      if (pendingUpcomingWebcastsParse)
         [self parseUpcomingWebcasts];
   } else {
      //TODO: inform a delegate (it should probably stop activity indicator).
   }
}

//________________________________________________________________________________________
- (void) connection : (NSURLConnection *) connection didFailWithError : (NSError *) error
{
   pendingHTMLStringLoad = NO;
   pendingRecentWebcastsParse = NO;
   pendingUpcomingWebcastsParse = NO;

   if (delegate && [delegate respondsToSelector : @selector(webcastsParser:didFailWithError:)])
      [delegate webcastsParser : self didFailWithError : error];
}

//________________________________________________________________________________________
- (void) parser : (CernMediaMARCParser *) parser didParseRecord : (NSDictionary *) record
{
   [recentWebcasts addObject : record];

   if (delegate && [delegate respondsToSelector : @selector(webcastsParser:didParseRecentWebcast:)])
      [delegate webcastsParser : self didParseRecentWebcast : record];
}

//________________________________________________________________________________________
- (void) parserDidFinish : (CernMediaMARCParser *) parser
{
    numParsersLoading--;

   if (!numParsersLoading) {
      // Sort the webcasts by date
      NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey : @"date" ascending : NO];
      recentWebcasts = [[recentWebcasts sortedArrayUsingDescriptors : @[sortDescriptor]] mutableCopy];

      if (delegate && [delegate respondsToSelector : @selector(webcastsParserDidFinishParsingRecentWebcasts:)])
         [delegate webcastsParserDidFinishParsingRecentWebcasts : self];
   }
}

#pragma mark - stop parser.

//________________________________________________________________________________________
- (void) stopParser
{
   if (currentConnection) {
      [currentConnection cancel];
      currentConnection = nil;
   }
}

@end
