//
//  TileView.m
//  CERN
//
//  Created by Timur Pocheptsov on 3/18/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <cassert>
#import <vector>

#import <CoreText/CoreText.h>

#import "ArticleDetailViewController.h"
#import "StoryboardIdentifiers.h"
#import "PictureButtonView.h"
#import "NewsTableViewCell.h"
#import "FeedItemTileView.h"
#import "NSString+HTML.h"


namespace CernAPP {

NSString * const feedItemSelectionNotification = @"CernAPP_FeedItemSelectionNotification";

}

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
const CGFloat hyphenShift = 5.f;

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

@implementation FeedItemTileView {
   MWFeedItem *feedItem;
   
   UIImageView *thumbnailView;
   NSMutableAttributedString * title;
   
   //Text in a tile:
   NSString *summary;
   NSMutableAttributedString * text;//TODO: better name
   CGFloat textLineHeight;
   NSString *softHyphen;
   CTFrameRef textFrame;
   CFStringTokenizerRef tokenizer;
   CTFrameRef titleFrame;

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
      
      summary = nullptr;
      text = nullptr;
      textLineHeight = 0.f;
      softHyphen = [NSString stringWithCString : "\u00AD" encoding : NSUTF8StringEncoding];
      textFrame = nullptr;
      tokenizer = nullptr;
      titleFrame = nullptr;

      
      //To be set from MWFeedItem later.
      wideImageOnTop = false;
      imageCut = 0;
      
      infoLabel = [[UILabel alloc] initWithFrame : CGRect()];
      infoLabel.textColor = [[UIColor blueColor] colorWithAlphaComponent : 0.5];
      UIFont * const font = [UIFont fontWithName : [NewsTableViewCell authorLabelFontName] size : 14.f];
      assert(font != nil && "initWithFrame, custom font is nil");
      infoLabel.font = font;
      [self addSubview : infoLabel];
      
      actionButton = [[PictureButtonView alloc] initWithFrame:CGRect() image : [UIImage imageNamed : @"action_blue.png"]];
      [actionButton addTarget : self selector : @selector(sendArticle)];
      [self addSubview : actionButton];

      //
      UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget : self action : @selector(showArticle)];
      [self addGestureRecognizer : tapRecognizer];
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
   
   if (tokenizer)
      CFRelease(tokenizer);
}

//________________________________________________________________________________________
- (void) setTileData : (MWFeedItem *) aFeedItem
{
   assert(aFeedItem != nil && "setTileData:, parameter 'feedItem' is nil");
   
   feedItem = aFeedItem;
   
   title = [[NSMutableAttributedString alloc] initWithString : aFeedItem.title ? [aFeedItem.title stringByConvertingHTMLToPlainText] : @"No title ... "];

   NSDateFormatter * const dateFormatter = [[NSDateFormatter alloc] init];
   [dateFormatter setDateFormat:@"d MMM. yyyy"];
   infoLabel.text = [dateFormatter stringFromDate : aFeedItem.date ? aFeedItem.date : [NSDate date]];

   summary = aFeedItem.summary ? [aFeedItem.summary stringByConvertingHTMLToPlainText] : @"";

   [self setAttributedTextFromSummary];
   [self setStringAttributes];
   
   thumbnailView.image = aFeedItem.image;
   imageCut = aFeedItem.imageCut;
   wideImageOnTop = aFeedItem.wideImageOnTop;
}

//________________________________________________________________________________________
- (void) setAttributedTextFromSummary
{
   //Modify summary:
   if (summary.length) {
      NSCharacterSet * const whitespaces = [NSCharacterSet whitespaceCharacterSet];
      NSPredicate * const noEmptyStrings = [NSPredicate predicateWithFormat : @"SELF != ''"];
      NSArray *parts = [summary componentsSeparatedByCharactersInSet : whitespaces];
      NSArray *filteredArray = [parts filteredArrayUsingPredicate : noEmptyStrings];
      summary = [filteredArray componentsJoinedByString : @" "];
   }

   if (!tokenizer) {
      tokenizer = CFStringTokenizerCreate(kCFAllocatorDefault, (CFStringRef)summary,
                                          CFRangeMake(0, summary.length),
                                          kCFStringTokenizerUnitWordBoundary,
                                          (__bridge CFLocaleRef)[NSLocale currentLocale]);
      if (!tokenizer)
         NSLog(@"TileView: -setTileData: - warning, CFStringTokenizerCreate failed");
   }
   
   [self hypenize];   
   text = [[NSMutableAttributedString alloc] initWithString : summary];
}

//________________________________________________________________________________________
- (void) setStringAttributes
{
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

   //Let's set text attributes:   
   //1. Font.
   UIFont * const textFont = [UIFont fontWithName : @"PTSans-Caption" size : 14.f];
   assert(textFont != nil && "setTileData:, text's font is nil");
   textLineHeight = [textFont lineHeight];
   const NSRange textRange = NSMakeRange(0, text.length);
   [text addAttribute : NSFontAttributeName value : textFont range : textRange];
   //2. Color
   [text addAttribute : NSForegroundColorAttributeName value : [UIColor darkGrayColor] range : textRange];
   //3. Alignment.
   NSMutableParagraphStyle * const textStyle = [[NSMutableParagraphStyle alloc] init];
   [textStyle setAlignment : NSTextAlignmentNatural];//NSTextAlignmentJustified];
   [text addAttribute : NSParagraphStyleAttributeName value : textStyle range : textRange];
}

//________________________________________________________________________________________
- (void) setTileThumbnail : (UIImage *) image
{
   assert(image != nil && "setTileThumbnail, parameter 'image' is nil");
   //CERN Courie's items have an image of size 1x1.
   const CGFloat minImageSize = 50.f;//??
   if (image.size.width < minImageSize || image.size.height < minImageSize)
      return;

   thumbnailView.image = image;
   [self layoutTile];
}

//________________________________________________________________________________________
- (BOOL) hasThumbnail
{
   return thumbnailView.image != nil;
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

#pragma mark - Interactions.

//________________________________________________________________________________________
- (void) sendArticle
{
}

//________________________________________________________________________________________
- (void) showArticle
{
   [[NSNotificationCenter defaultCenter] postNotificationName : CernAPP::feedItemSelectionNotification object : feedItem];
}

#pragma mark - text rendering.
//________________________________________________________________________________________
- (void) drawRect : (CGRect) rect
{
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
   
   if (textFrame)
      [self drawText : ctx];
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
   
   CGFloat topY = 0.f;

   if (!thumbnailView.image) {
      //The simplest possible case - text fills the whole tile.
      topY = titleH * h;
   } else if (IsWideImage(thumbnailView.image)) {
      //Tile's top or bottom is occupied by a wide image.
      if (wideImageOnTop)
         topY = titleH * h + textH * h * 0.5f;
      else
         topY = titleH * h;
   } else {
      topY = titleH * h;
   }
   
   CGContextSaveGState(ctx);
   //
   CGContextSetTextMatrix(ctx, CGAffineTransformIdentity);
   CGContextTranslateCTM(ctx, 0, self.frame.size.height);
   CGContextScaleCTM(ctx, 1.f, -1.f);

   //We have a rect and a CTFrame created from this rect.
   //We still have to insert '-' sumbol in case we have a soft-hyphen at the end of CTLine
   //(Core Text does not insert hard-hyphen, unfortunately) :(
   
   if (CFArrayRef ctLines = CTFrameGetLines(textFrame)) {
      if (CFIndex nLines = CFArrayGetCount(ctLines)) {
         assert(nLines > 0 && "drawTextInRect, array count is negative");//CFIndex is signed long, so API can return crap. :)

         std::vector<CGPoint> lineOrigins(nLines);
         CTFrameGetLineOrigins(textFrame, CFRangeMake(0, nLines), &lineOrigins[0]);

         for (CFIndex i = 0; i < nLines; ++i) {
            topY += textLineHeight;
            const CGFloat x = lineOrigins[i].x + w * wideImageMargin;
            CGContextSetTextPosition(ctx, x, [self translateY : topY]);
            
            //Now check, if this CTLine end with a soft hyphen.
            CTLineRef ctLine = (CTLineRef)CFArrayGetValueAtIndex(ctLines, i);
            const CFRange cfStringRange = CTLineGetStringRange(ctLine);
            const NSRange stringRange = NSMakeRange(cfStringRange.location, cfStringRange.length);
            const UniChar lastChar = [summary characterAtIndex : stringRange.location + stringRange.length - 1];
            
            if (lastChar != 0xAD)
               CTLineDraw(ctLine, ctx);
            else {
               NSMutableAttributedString * const lineAttrString = [[text attributedSubstringFromRange : stringRange] mutableCopy];
               const NSRange replaceRange = NSMakeRange(stringRange.length - 1, 1);
               [lineAttrString replaceCharactersInRange : replaceRange withString : @"-"];

               if (CTLineRef hyphenLine = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)lineAttrString)) {
                  CTLineDraw(hyphenLine, ctx);
                  CFRelease(hyphenLine);
               }
            }
         }
      }
   }

   CGContextRestoreGState(ctx);
}

#pragma mark - Soft hyphens
//________________________________________________________________________________________
- (void) hypenize
{
   //TODO: this function looks terrible, fix it.
   
   //Tokens - I think, I can not avoid this.
   //Substrings - I do not know, may be there is another way.

   if (!tokenizer || !summary.length)
      return;
   
   @autoreleasepool {   
      CFStringTokenizerSetString(tokenizer, (__bridge CFStringRef)summary, CFRangeMake(0, summary.length));
      CFRange tokenRange = CFRangeMake(0, summary.length);

      std::vector<NSUInteger> hyphens;
      std::vector<NSUInteger> tokenHyphens;
      tokenHyphens.reserve(8);//hehe
      
      while (true) {
         tokenHyphens.clear();
         const CFStringTokenizerTokenType tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer);
         if (tokenType == kCFStringTokenizerTokenNone)
            break;//????

         tokenRange = CFStringTokenizerGetCurrentTokenRange(tokenizer);
         if (tokenRange.location == kCFNotFound)
            break;

         if (tokenType != kCFStringTokenizerTokenHasNonLettersMask) {
            //Try to find hyphen positions.
            while (tokenRange.length) {
               const CFIndex newPos = CFStringGetHyphenationLocationBeforeIndex((__bridge CFStringRef)summary, tokenRange.location + tokenRange.length,
                                                                                tokenRange, 0,
                                                                                (__bridge CFLocaleRef)[NSLocale currentLocale],
                                                                                nullptr);
               if (newPos == kCFNotFound)
                  break;
               
               assert(newPos >= tokenRange.location && newPos < tokenRange.location + tokenRange.length &&
                      "hyphenize, invalid hyphen location");
               
               tokenHyphens.push_back(newPos);
               tokenRange.length = newPos - tokenRange.location;
            }
            
            if (tokenHyphens.size())
               hyphens.insert(hyphens.end(), tokenHyphens.rbegin(), tokenHyphens.rend());
         }
      }
      
      NSMutableString *hyphenized = [[NSMutableString alloc] init];
      //:((( append requires only string, can not be a range :(((
      NSUInteger start = 0;
      for (auto hyphenPos : hyphens) {
         assert(hyphenPos > 0 && hyphenPos < summary.length && "hyphenize, invalid hyphen location");
         NSString * const subs = [summary substringWithRange : NSMakeRange(start, hyphenPos - start)];
         [hyphenized appendString : subs];
         [hyphenized appendString : softHyphen];
         start = hyphenPos;
      }

      [hyphenized appendString : [summary substringWithRange:NSMakeRange(start, summary.length - start)]];
      summary = hyphenized;
   }
}

@end
