//
//  NSString+StringSizeWithFont.m
//  CERN
//
//  Created by Fons Rademakers on 24/08/2014.
//  Copyright (c) 2014 CERN. All rights reserved.
//

#import "NSString+StringSizeWithFont.h"

@implementation NSString (StringSizeWithFont)

- (CGSize)sizeWithFont7:(UIFont*)font
{
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_7_0
   CGSize s = [self sizeWithAttributes: @{NSFontAttributeName: font}];
   // round up to nearest integer
   s.height = ceilf(s.height);
   s.width  = ceilf(s.width);
   return s;
#else
   return [self sizeWithFont: font];
#endif
}

- (CGSize)sizeWithFont7:(UIFont*)font constrainedToSize:(CGSize)size
{
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_7_0
   CGSize s = [self boundingRectWithSize: size options: NSStringDrawingUsesLineFragmentOrigin attributes: @{NSFontAttributeName:font} context: nil].size;
   // round up to nearest integer
   s.height = ceilf(s.height);
   s.width  = ceilf(s.width);
   return s;
#else
   CGSize s = [self sizeWithFont: font constrainedToSize: size];
   // round up to nearest integer
   s.height = ceilf(s.height);
   s.width  = ceilf(s.width);
   return s;
#endif
}

- (CGSize)sizeWithFont7:(UIFont*)font constrainedToSize:(CGSize)size lineBreakMode:(NSLineBreakMode)lineBreakMode
{
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_7_0
   // set linebreak mode
   NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
   [style setLineBreakMode: lineBreakMode];
   NSDictionary *attributes = @{NSFontAttributeName: font, NSParagraphStyleAttributeName: style};
   CGSize s = [self boundingRectWithSize:size options: NSStringDrawingUsesLineFragmentOrigin attributes: attributes context: nil].size;
   // round up to nearest integer
   s.height = ceilf(s.height);
   s.width  = ceilf(s.width);
   return s;
#else
   CGSize s = [self sizeWithFont: font constrainedToSize: size lineBreakMode: lineBreakMode];
   // round up to nearest integer
   s.height = ceilf(s.height);
   s.width  = ceilf(s.width);
   return s;
#endif
}

@end
