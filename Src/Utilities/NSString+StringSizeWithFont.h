//
//  NSString+StringSizeWithFont.h
//  CERN
//
//  Created by Fons Rademakers on 24/08/2014.
//  Copyright (c) 2014 CERN. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface NSString (StringSizeWithFont)

// Wrap the verbose >=iOS7 string size methods in a <iOS7 compatible form
- (CGSize)sizeWithFont7:(UIFont*)font;
- (CGSize)sizeWithFont7:(UIFont*)font constrainedToSize:(CGSize)size;
- (CGSize)sizeWithFont7:(UIFont*)font constrainedToSize:(CGSize)size lineBreakMode:(NSLineBreakMode)lineBreakMode;

@end
