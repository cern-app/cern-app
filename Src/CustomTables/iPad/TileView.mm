//
//  TileView.m
//  CERN
//
//  Created by Timur Pocheptsov on 3/18/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <cassert>
#import <cstdlib>

#import <CoreText/CoreText.h>

#import "PictureButtonView.h"
#import "NewsTableViewCell.h"
#import "NSString+HTML.h"
#import "TileView.h"

namespace {

//Different geometry constants, all in percents.
const CGFloat wideImageMargin = 0.08;

const CGFloat titleH = 0.18f;
const CGFloat footerY = 0.9f;
const CGFloat textH = footerY - titleH;
const CGFloat wideImageH = 0.5 * textH;

const CGFloat upCutH = 0.2;
const CGFloat downCutH = textH - upCutH;

//
const CGFloat hyphenShift = 8.f;

//________________________________________________________________________________________
bool IsWideImage(UIImage *image)
{
   assert(image != nil && "IsWideImage, parameter 'image' is nil");

   const CGSize imageSize = image.size;

   if (!imageSize.width || !imageSize.height)
      return false;

   return imageSize.width / imageSize.height >= 2.f;
}

}

@implementation TileView {
   UIImageView *thumbnailView;
   NSMutableAttributedString * title;
   
   NSString *summary;
   NSMutableAttributedString * text;
   CGFloat textMetricHeight;
   
   CTFrameRef titleFrame;
   CTFrameRef textFrame;
   
   bool wideImageOnTop;
   int imageCut;
   
   UILabel *infoLabel;//Article's date and author.

   PictureButtonView *actionButton;
}

//________________________________________________________________________________________
- (CGFloat) translateY : (CGFloat) y
{
   return self.frame.size.height - y;
}

//________________________________________________________________________________________
- (id) initWithFrame : (CGRect) frame
{
   if (self = [super initWithFrame : frame]) {
      thumbnailView = [[UIImageView alloc] initWithFrame : CGRect()];
      thumbnailView.contentMode = UIViewContentModeScaleAspectFill;
      thumbnailView.clipsToBounds = YES;
      [self addSubview : thumbnailView];
      
      self.backgroundColor = [UIColor whiteColor];
      
      titleFrame = nullptr;
      textFrame = nullptr;
      
      wideImageOnTop = std::rand() % 2;
      imageCut = std::rand() % 4;
      
      infoLabel = [[UILabel alloc] initWithFrame : CGRect()];
      infoLabel.textColor = [[UIColor blueColor] colorWithAlphaComponent : 0.5];
      UIFont * const font = [UIFont fontWithName : [NewsTableViewCell authorLabelFontName] size : 14.f];
      assert(font != nil && "initWithFrame, custom font is nil");
      infoLabel.font = font;
      [self addSubview : infoLabel];
      
      actionButton = [[PictureButtonView alloc] initWithFrame:CGRect() image : [UIImage imageNamed : @"action_blue.png"]];
      [actionButton addTarget : self selector : @selector(sendArticle)];
      [self addSubview : actionButton];
      
      textMetricHeight = 0.f;
   }

   return self;
}

//________________________________________________________________________________________
- (void) dealloc
{
   if (titleFrame)
      CFRelease(titleFrame);
   
   if (textFrame)
      CFRelease(textFrame);
}

//________________________________________________________________________________________
- (void) setTileData : (MWFeedItem *) feedItem
{
   assert(feedItem != nil && "setTileData:, parameter 'feedItem' is nil");
   
   title = [[NSMutableAttributedString alloc] initWithString : feedItem.title ? [feedItem.title stringByConvertingHTMLToPlainText] : @"No title ... "];

   NSDateFormatter * const dateFormatter = [[NSDateFormatter alloc] init];
   [dateFormatter setDateFormat:@"d MMM. yyyy"];
   infoLabel.text = [dateFormatter stringFromDate : feedItem.date ? feedItem.date : [NSDate date]];

   //Let's now set attributes:   
   //1. Font.
   UIFont * const titleFont = [UIFont fontWithName : @"PTSans-Bold" size : 20.f];
   assert(titleFont != nil && "setTileData:, titles' font is nil");
   const NSRange titleRange = NSMakeRange(0, title.length);
   [title addAttribute : NSFontAttributeName value : titleFont range : titleRange];
   
   //2. Text alignment.
   NSMutableParagraphStyle * const style = [[NSMutableParagraphStyle alloc] init];
   [style setAlignment : NSTextAlignmentCenter];
   [title addAttribute : NSParagraphStyleAttributeName value : style range : titleRange];
   
   summary = feedItem.summary ? [feedItem.summary stringByConvertingHTMLToPlainText] : @"";
   if (summary.length) {
      NSCharacterSet * const whitespaces = [NSCharacterSet whitespaceCharacterSet];
      NSPredicate * const noEmptyStrings = [NSPredicate predicateWithFormat : @"SELF != ''"];
      NSArray *parts = [summary componentsSeparatedByCharactersInSet : whitespaces];
      NSArray *filteredArray = [parts filteredArrayUsingPredicate : noEmptyStrings];
      summary = [filteredArray componentsJoinedByString : @" "];
   }
   
   text = [[NSMutableAttributedString alloc] initWithString : summary];   

   //Let's set text attributes:   
   //1. Font.
   UIFont * const textFont = [UIFont fontWithName : @"PTSans-Caption" size : 14.f];
   assert(textFont != nil && "setTileData:, text's font is nil");
   const NSRange textRange = NSMakeRange(0, text.length);
   [text addAttribute : NSFontAttributeName value : textFont range : textRange];
   //2. Color
   [text addAttribute : NSForegroundColorAttributeName value : [UIColor darkGrayColor] range : textRange];
   //3. Alignment.
   NSMutableParagraphStyle * const textStyle = [[NSMutableParagraphStyle alloc] init];
   [textStyle setAlignment : NSTextAlignmentNatural];//NSTextAlignmentJustified];
   [text addAttribute : NSParagraphStyleAttributeName value : textStyle range : textRange];
   
   [self calculateTextFontMetrics];
}

//________________________________________________________________________________________
- (void) setTileThumbnail:(UIImage *) image
{
   assert(image != nil && "setTileThumbnail, parameter 'image' is nil");
   thumbnailView.image = image;
   [self layoutTile];
}

//________________________________________________________________________________________
- (CGPathRef) createTextPath
{
   const CGFloat w = self.frame.size.width;
   const CGFloat h = self.frame.size.height;

   if (!thumbnailView.image) {
      //The simplest possible case.
      CGRect textRect = CGRectMake(wideImageMargin * w, [self translateY : titleH * h + textH * h], w - 2 * wideImageMargin * w, h * textH);

      return CGPathCreateWithRect(textRect, &CGAffineTransformIdentity);
   } else if (IsWideImage(thumbnailView.image)) {
      CGRect textRect = {};
      if (wideImageOnTop)
         textRect = CGRectMake(wideImageMargin * w, [self translateY : titleH * h + textH * h], w - 2 * wideImageMargin * w, 0.5f * h * textH);
      else
         textRect = CGRectMake(wideImageMargin * w, [self translateY : titleH * h + 0.5f * textH * h], w - 2 * wideImageMargin * w, 0.5f * h * textH);

      return CGPathCreateWithRect(textRect, &CGAffineTransformIdentity);
      //Layout image view!
   } else {
      CGMutablePathRef path = CGPathCreateMutable();
      const CGFloat y1 = [self translateY : textH * h * 0.5f + titleH * h];
      const CGFloat y2 = [self translateY : textH * h + titleH * h];
   
      //At the beginning I was adding rectangle sub-paths, but ...
      //there is a visible gap between text in these rectangles.

      switch (imageCut) {
      case 0 :
         CGPathMoveToPoint(path, &CGAffineTransformIdentity, wideImageMargin * w, y2);
         CGPathAddLineToPoint(path, &CGAffineTransformIdentity, wideImageMargin * w, y1);
         CGPathAddLineToPoint(path, &CGAffineTransformIdentity, w / 2, y1);
         CGPathAddLineToPoint(path, &CGAffineTransformIdentity, w / 2, y1 + textH * 0.5 * h);
         CGPathAddLineToPoint(path, &CGAffineTransformIdentity, w - w * wideImageMargin, y1 + textH * 0.5 * h);
         CGPathAddLineToPoint(path, &CGAffineTransformIdentity, w - w * wideImageMargin, y2);
         CGPathCloseSubpath(path);
         break;
      case 1:
         CGPathMoveToPoint(path, &CGAffineTransformIdentity, wideImageMargin * w, y2);
         CGPathAddLineToPoint(path, &CGAffineTransformIdentity, wideImageMargin * w, y2 + textH * h);
         CGPathAddLineToPoint(path, &CGAffineTransformIdentity, w / 2, y2 + textH * h);
         CGPathAddLineToPoint(path, &CGAffineTransformIdentity, w / 2, y1);
         CGPathAddLineToPoint(path, &CGAffineTransformIdentity, w - w * wideImageMargin, y1);
         CGPathAddLineToPoint(path, &CGAffineTransformIdentity, w - w * wideImageMargin, y2);
         CGPathCloseSubpath(path);
         
         
         break;
      case 2:
         CGPathMoveToPoint(path, &CGAffineTransformIdentity, wideImageMargin * w, y1);
         CGPathAddLineToPoint(path, &CGAffineTransformIdentity, wideImageMargin * w, y2 + textH * h);
         CGPathAddLineToPoint(path, &CGAffineTransformIdentity, w - w * wideImageMargin, y2 + textH * h);
         CGPathAddLineToPoint(path, &CGAffineTransformIdentity, w - w * wideImageMargin, y2);
         CGPathAddLineToPoint(path, &CGAffineTransformIdentity, w / 2, y2);
         CGPathAddLineToPoint(path, &CGAffineTransformIdentity, w / 2, y1);
         CGPathCloseSubpath(path);

         break;
      case 3:
         CGPathMoveToPoint(path, &CGAffineTransformIdentity, wideImageMargin * w, y2);
         CGPathAddLineToPoint(path, &CGAffineTransformIdentity, wideImageMargin * w, y2 + textH * h);
         CGPathAddLineToPoint(path, &CGAffineTransformIdentity, w -  w * wideImageMargin, y2 + textH * h);
         CGPathAddLineToPoint(path, &CGAffineTransformIdentity, w -  w * wideImageMargin, y1);
         CGPathAddLineToPoint(path, &CGAffineTransformIdentity, w / 2, y1);
         CGPathAddLineToPoint(path, &CGAffineTransformIdentity, w / 2, y2);
         CGPathCloseSubpath(path);

         break;
      default:
         assert(0 && "createTextPathAndLayoutImage, unknown layout");
         break;
      }

      return path;
   }
}

//________________________________________________________________________________________
- (void) layoutTitle
{
   if (titleFrame)
      CFRelease(titleFrame);

   const CGFloat w = self.frame.size.width;
   const CGFloat h = self.frame.size.height;
   
   //Title frame is always simple.
   const CGRect titleRect = CGRectMake(0.f, [self translateY : titleH * h], w, h * titleH);
   CGPathRef titlePath = CGPathCreateWithRect(titleRect, &CGAffineTransformIdentity);
   CTFramesetterRef titleSetter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)title);
   titleFrame = CTFramesetterCreateFrame(titleSetter, CFRangeMake(0, [title length]), titlePath, nullptr);
   
   CGPathRelease(titlePath);
   CFRelease(titleSetter);
}

//________________________________________________________________________________________
- (void) layoutText
{
   if (textFrame)
      CFRelease(textFrame);

   CGPathRef textPath = [self createTextPath];
   if (textPath) {
      CTFramesetterRef textSetter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)text);
      textFrame = CTFramesetterCreateFrame(textSetter, CFRangeMake(0, [text length]), textPath, nullptr);
      CFRelease(textSetter);
      CFRelease(textPath);
   }
}

//________________________________________________________________________________________
- (void) layoutThumbnail
{
   if (thumbnailView.image) {
      const CGFloat w = self.frame.size.width;
      const CGFloat h = self.frame.size.height;

      if (IsWideImage(thumbnailView.image)) {
         CGRect imageRect = {};
         if (wideImageOnTop)
            imageRect = CGRectMake(wideImageMargin * w, titleH * h, w - 2 * wideImageMargin * w, 0.5f * h * textH);
         else
            imageRect = CGRectMake(wideImageMargin * w, titleH * h + textH * h * 0.5f, w - 2 * wideImageMargin * w, 0.5f * h * textH);

         thumbnailView.frame = imageRect;
      } else {
         switch (imageCut) {
         case 0:
            thumbnailView.frame = CGRectMake(wideImageMargin * w + 5, titleH * h + 5, (w - 2 * w * wideImageMargin) * 0.5 - 10, h * textH * 0.5 - 10);
            break;
         case 1:
            thumbnailView.frame = CGRectMake(w / 2 + 5, titleH * h + 5, (w - 2 * w * wideImageMargin) * 0.5 - 10, h * textH * 0.5 - 10);
            break;
         case 2:
            thumbnailView.frame = CGRectMake(wideImageMargin * w + 5, titleH * h + 5 + textH * 0.5 * h, (w - 2 * w * wideImageMargin) * 0.5 - 10, h * textH * 0.5 - 10);
            break;
         case 3:
            thumbnailView.frame = CGRectMake(w / 2 + 5, titleH * h + 5 + textH * 0.5 * h, (w - 2 * w * wideImageMargin) * 0.5 - 10, h * textH * 0.5 - 10);
            break;
         default:
            assert(0 && "layoutThumbnail, unknown layout");
            break;
         }
      }
   }
}

//________________________________________________________________________________________
- (void) layoutUIElements
{
   const CGFloat hugeH = 1000.f;
   const CGSize viewSize = self.frame.size;
   const CGSize dateSize = [infoLabel.text sizeWithFont : infoLabel.font constrainedToSize : CGSizeMake(viewSize.width / 2, hugeH)];
   const CGFloat y = footerY * viewSize.height + (1 - footerY) * viewSize.height * 0.5 - dateSize.height / 2;
   infoLabel.frame = CGRectMake(wideImageMargin * viewSize.width, y, dateSize.width, dateSize.height);
   
   const CGFloat btnSz = (1 - footerY) * viewSize.height;//quite arbitrary choise
   actionButton.frame = CGRectMake(viewSize.width - btnSz, viewSize.height - btnSz, btnSz, btnSz);
}

//________________________________________________________________________________________
- (void) layoutTile
{
   [self layoutTitle];
   [self layoutText];
   [self layoutThumbnail];
   [self layoutUIElements];
   
   [self setNeedsDisplay];
}

//________________________________________________________________________________________
- (void) sendArticle
{
}

#pragma mark - text rendering.
//________________________________________________________________________________________
- (void) drawRect : (CGRect) rect
{
   [super drawRect : rect];
   
   CGContextRef ctx = UIGraphicsGetCurrentContext();

   CGContextSetRGBStrokeColor(ctx, 0.f, 0.f, 0.f, 1.f);

   CGContextSetTextMatrix(ctx, CGAffineTransformIdentity);
   CGContextTranslateCTM(ctx, 0, rect.size.height);
   CGContextScaleCTM(ctx, 1.f, -1.f);

   if (titleFrame)
      CTFrameDraw(titleFrame, ctx);
   
   if (textFrame)
      CTFrameDraw(textFrame, ctx);
   
   /*
   [super drawRect : rect];
   
   CGContextRef ctx = UIGraphicsGetCurrentContext();

   CGContextSetRGBStrokeColor(ctx, 0.f, 0.f, 0.f, 1.f);

   CGContextSaveGState(ctx);
   CGContextSetTextMatrix(ctx, CGAffineTransformIdentity);
   CGContextTranslateCTM(ctx, 0, rect.size.height);
   CGContextScaleCTM(ctx, 1.f, -1.f);

   if (titleFrame)
      CTFrameDraw(titleFrame, ctx);
   
   CGContextRestoreGState(ctx);
   
   [self drawText : ctx];
   */
}

//________________________________________________________________________________________
- (void) drawText : (CGContextRef) ctx
{
   assert(ctx != nullptr && "drawText, parameter 'ctx' is null");
   
   //We have 6 possible tile's layouts:
   //1. Text fills the full tile (no thumbnails found)
   //2. Text fills half of a tile area (we have wide thumbnail image) - either upper or lower half.
   //3. Tuhmbnail image occupies 1/4 of tile's area, it in the top-left, top-right, bottom-left,
   //   bottom-right quarter of a tile. (4 possible layouts).
   //In any case, the text is filling some rectangle, and even in case 3 we can split
   //a text area into 2 rectangles.

   const CGFloat w = self.frame.size.width;
   const CGFloat h = self.frame.size.height;

   if (!thumbnailView.image) {
      //The simplest possible case - 1.
      CGRect textRect = CGRectMake(wideImageMargin * w, titleH * h, w - 2 * wideImageMargin * w, h * textH);
      [self drawText : ctx fitInRect : textRect fromIndex : 0 insertEllipsis : YES];
   } else if (IsWideImage(thumbnailView.image)) {
      //Case 2.
      CGRect textRect = {};
      if (wideImageOnTop)
         textRect = CGRectMake(wideImageMargin * w, titleH * h + textH * h * 0.5f, w - 2 * wideImageMargin * w, 0.5f * h * textH);
      else
         textRect = CGRectMake(wideImageMargin * w, titleH * h, w - 2 * wideImageMargin * w, 0.5f * h * textH);

      [self drawText : ctx fitInRect : textRect fromIndex : 0 insertEllipsis : YES];
   } else {
      CGRect textRect = [self getFirstTextRectangle];
      const NSUInteger next = [self drawText : ctx fitInRect : textRect fromIndex : 0 insertEllipsis : NO];
      if (next < text.length) {
         //We have even more text.
         textRect = [self getSecondTextRectangle];
         [self drawText:ctx fitInRect : textRect fromIndex : next insertEllipsis : YES];
      }
   }
}

//________________________________________________________________________________________
- (NSUInteger) drawText : (CGContextRef) ctx fitInRect : (CGRect) rect fromIndex : (NSUInteger) startIndex insertEllipsis : (BOOL) ellipsis
{
   assert(ctx != nullptr && "drawText:fitInRect:fromIndex:, parameter 'ctx' is null");
   assert(rect.size.width > 0.f && rect.size.height > 0.f &&
          "drawText:fitInRect:fromIndex:, parameter 'rect' is not a valid rectangle");
   assert(startIndex < text.length && "drawText:fitInRect:fromIndex:, parameter 'startIndex' is out of range");
   
   //test test test!
   CGContextSetRGBStrokeColor(ctx, 1.f, 0.f, 0.f, 1.f);
   CGContextStrokeRect(ctx, rect);
   
   CGContextSaveGState(ctx);
   //
   CGContextSetTextMatrix(ctx, CGAffineTransformIdentity);
   CGContextTranslateCTM(ctx, 0, rect.size.height);
   CGContextScaleCTM(ctx, 1.f, -1.f);
   
   //Time for the magic.
   CTTypesetterRef typesetter = CTTypesetterCreateWithAttributedString((__bridge CFAttributedStringRef)text);
   if (!typesetter) {
      NSLog(@"drawText:fitInRect:fromIndex:insertEllipsis:, typesetter creation failed");
      return text.length;//We'll stop text rendering for this tile.
   }
   
   CGPoint currentTextPos = rect.origin;
   while (true) {
      const CFIndex lineBreak = CTTypesetterSuggestLineBreak(typesetter, startIndex, rect.size.width);
      assert(lineBreak >= 0 && "drawText:fitInRect:fromIndex:insertEllipsis:, suggested line break is negative");
      assert(startIndex + lineBreak <= text.length && "drawText:fitInRect:fromIndex:insertEllipsis:, suggested line break is out of bounds");

      if (startIndex + lineBreak < text.length) {
         CFStringTokenizerRef tokenizer = CFStringTokenizerCreate(kCFAllocatorDefault, (CFStringRef)summary, CFRangeMake(startIndex + lineBreak, summary.length - startIndex - lineBreak),
                                                            kCFStringTokenizerUnitWordBoundary, (__bridge CFLocaleRef)[NSLocale currentLocale]);
         CFStringTokenizerTokenType tokenType =  CFStringTokenizerAdvanceToNextToken(tokenizer);

         if (tokenType == kCFStringTokenizerTokenNone || tokenType == kCFStringTokenizerTokenHasNonLettersMask) {
            //Do nothing special, just draw a line till suggested line break.
            [self drawTextLine : ctx from : startIndex withLength : lineBreak - startIndex atPoint : currentTextPos];
            currentTextPos.y += textMetricHeight;
            startIndex = lineBreak;
         } else {
            //Aha, we try to do a hyphenation!
            const CFRange tokenRange = CFStringTokenizerGetCurrentTokenRange(tokenizer);
            const CGRect textRect = CGRectMake(currentTextPos.x, currentTextPos.y, rect.size.width, textMetricHeight);
            startIndex = [self drawHiphenated:ctx from:startIndex withLength:lineBreak - startIndex inArea : textRect addToken : tokenRange];
         }
      } else {
         [self drawTextLine : ctx from : startIndex withLength : lineBreak - startIndex atPoint : currentTextPos];
      }
      
      break;
   }

   //
   CGContextRestoreGState(ctx);
   
   return 1;
}

//________________________________________________________________________________________
- (void) drawTextLine : (CGContextRef) ctx from : (NSUInteger) startIndex withLength : (NSUInteger) length atPoint : (CGPoint) xy
{
   //This function draws a text line.
   NSAttributedString * const substring = [text attributedSubstringFromRange : NSMakeRange(startIndex, length)];
   CTLineRef ctLine = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)substring);
   
   xy.y = [self translateY : xy.y];

   CGContextSetTextPosition(ctx, xy.x, xy.y);
   CTLineDraw(ctLine, ctx);
   CFRelease(ctLine);
}

//________________________________________________________________________________________
- (NSUInteger) drawHiphenated : (CGContextRef) ctx from : (NSUInteger) startIndex withLength : (NSUInteger) length inArea : (CGRect) area
            addToken : (CFRange) tokenToSplit
{
   //We have a line that fits (somehow) into the area.size.width. We also have a next token,
   //which is, probably, a legal word. Try to add a hyphen and draw a part of this word, if
   //it still fits into the rectangle.
   area.origin.y = [self translateY : area.origin.y - textMetricHeight];
   
   while (true) {
      const CFIndex hyphenIndex = CFStringGetHyphenationLocationBeforeIndex((__bridge CFStringRef)summary, tokenToSplit.location + tokenToSplit.length,
                                                                            tokenToSplit, 0, (__bridge CFLocaleRef)[NSLocale currentLocale], nullptr);
      if (hyphenIndex != kCFNotFound && hyphenIndex > tokenToSplit.location) {
         NSAttributedString * const test = [text attributedSubstringFromRange : NSMakeRange(startIndex, hyphenIndex - startIndex)];
         CTLineRef ctLine = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)test);
         CGFloat ascent = 0.f, descent = 0.f, leading = 0.f;
         const CGFloat width = CTLineGetTypographicBounds(ctLine, &ascent, &descent, &leading);
         CFRelease(ctLine);
         if (width <= area.size.width + hyphenShift) {
            [self drawTextLine : ctx from : startIndex withLength : hyphenIndex - startIndex atPoint:area.origin];
            break;
         } else {
            tokenToSplit.length = hyphenIndex - tokenToSplit.location;
         }
      } else {
         [self drawTextLine:ctx from:startIndex withLength:length atPoint:area.origin];
         break;
      }
      
      break;//The code does not really work at the moment, just a test.
   }
   
   return 0;
}

#pragma mark - Aux. text rendering functions.

//________________________________________________________________________________________
- (CGRect) getFirstTextRectangle
{
   //At the moment, if I have a thumbnail (not a wide image),
   //image fills 1/4 of tile's area.
   //I split the remaining text area into two rectangles.
   //This is the "first" rectangle.
   const CGFloat w = self.frame.size.width;
   const CGFloat h = self.frame.size.height;

   CGRect textRect = {};
   
   switch (imageCut) {
   case 0:
      textRect = CGRectMake(w / 2, titleH * h, (w - 2 * w * wideImageMargin) / 2, textH * h * 0.5f);
      break;
   case 1:
      textRect = CGRectMake(w * wideImageMargin, titleH * h, (w - 2 * w * wideImageMargin) / 2 - hyphenShift, textH * h * 0.5f);
      break;
   case 2:
   case 3:
      textRect = CGRectMake(wideImageMargin * w, titleH * h, w - 2 * w * wideImageMargin, textH * h * 0.5f);
      break;
   default:
      assert(0 && "getFirstTextRectangle, unknown layout");
      break;
   }
   
   return textRect;
}

//________________________________________________________________________________________
- (CGRect) getSecondTextRectangle
{
   //At the moment, if I have a thumbnail (not a wide image),
   //image fills 1/4 of tile's area.
   //I split the remaining text area into two rectangles.
   //This is the "second" rectangle.
   const CGFloat w = self.frame.size.width;
   const CGFloat h = self.frame.size.height;
   const CGFloat y1 = textH * h * 0.5f + titleH * h;

   CGRect textRect = {};
   
   switch (imageCut) {
   case 0:
   case 1:
      textRect = CGRectMake(wideImageMargin * w, y1, w - 2 * w * wideImageMargin, textH * h * 0.5f);
      break;
   case 2:
      textRect = CGRectMake(w / 2, y1, (w - 2 * w * wideImageMargin) * 0.5f, textH * h * 0.5f);
      break;
   case 3:
      textRect = CGRectMake(wideImageMargin * w, y1, (w - 2 * w * wideImageMargin) * 0.5f - hyphenShift, textH * h * 0.5f);
      break;
   default:
      assert(0 && "getFirstTextRectangle, unknown layout");
      break;
   }
   
   return textRect;
}

//________________________________________________________________________________________
- (void) calculateTextFontMetrics
{
   assert(text != nil && "calculateTextFontMetrics, text string is nil");
   
   //Font metric - height.
   CTLineRef ctLine = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)text);
   assert(ctLine != nullptr && "calculateTextFontMetrics, CTLineCreateWithAttributedString failed");


   CGFloat ascent = 0.f, descent = 0.f, leading = 0.f;
   CTLineGetTypographicBounds(ctLine, &ascent, &descent, &leading);
   
   textMetricHeight = ascent + descent;//hehehe

   CFRelease(ctLine);
}

@end
