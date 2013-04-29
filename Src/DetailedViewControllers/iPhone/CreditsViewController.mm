//
//  CreditsViewController.m
//  CERN
//
//  Created by Timur Pocheptsov on 2/15/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <cassert>

#import "CreditsViewController.h"

@implementation CreditsViewController {
   NSMutableAttributedString *text;
   UIColor *captionColor;
}

//________________________________________________________________________________________
- (id) initWithNibName : (NSString *) nibNameOrNil bundle : (NSBundle *) nibBundleOrNil
{
   if (self = [super initWithNibName : nibNameOrNil bundle : nibBundleOrNil]) {
      // Custom initialization
   }

   return self;
}

//________________________________________________________________________________________
- (void) viewDidLoad
{
   [super viewDidLoad];

   text = [[NSMutableAttributedString alloc] init];
   
   captionColor = [UIColor colorWithRed : 0.f green : 83.f / 255.f blue : 161.f / 255.f alpha : 1.f];

   [self addVersionInfo];
   [self addDevelopersInfo];
   [self addReadabilityInfo];
   
   [self addComponentInfo : @"\nECSlidingViewController:" licenseFile : @"ECSlidingViewControllerLicense" author : @"Michael Enriquez"];
   [self addComponentInfo : @"\nMWFeedParser:" licenseFile : @"MWFeedParserLicense" author : @"Michael Waterfall"];
   [self addComponentInfo : @"\nMWPhotoBrowser:" licenseFile : @"MWPhotoBrowserLicense" author : @"Michael Waterfall"];
   [self addComponentInfo : @"\nMBProgressHUD:" licenseFile : @"MBProgressHUDLicense" author : @"Matej Bukovinski"];
   [self addComponentInfo : @"\nSDWebImage:" licenseFile : @"SDWebImageLicense" author : @"Olivier Poitrey"];
   [self addComponentInfo : @"\nGlyphsPro (v.1):" licenseFile : @"glyphspro_1_license" author : @"Joseph Wain"];
   [self addComponentInfo : @"\nGlyphsPro (v.4):" licenseFile : @"glyphspro_4_license" author : @"Joseph Wain"];
   [self addIconsInfo];

   textView.attributedText = text;
}

//________________________________________________________________________________________
- (void) didReceiveMemoryWarning
{
   [super didReceiveMemoryWarning];
   //Dispose of any resources that can be recreated.
}

//________________________________________________________________________________________
- (IBAction) donePressed : (id) sender
{
   [self dismissViewControllerAnimated : YES completion : nil];
}

#pragma mark - Compose the text.

//________________________________________________________________________________________
- (void) setCaptionAttribute : (NSRange) range
{
   UIFont * const titleFont = [UIFont fontWithName : @"PTSans-Bold" size : 20.f];
   assert(titleFont != nil && "setCaptionAttribute:, font is nil");
   
   [text addAttribute : NSFontAttributeName value : titleFont range : range];
   [text addAttribute : NSForegroundColorAttributeName value : captionColor range : range];
}

//________________________________________________________________________________________
- (void) setFont : (UIFont *) font color : (UIColor *) color forRange : (NSRange) range
{
   assert(font != nil && "setFont:color:forRange:, parameter 'font' is nil");
   assert(color != nil && "setFont:color:forRange:, parameter 'color' is nil");
   assert(range.location < text.length && range.location + range.length <= text.length &&
          "setFont:color:forRange:, parameter 'range' is invalid");
   
   [text addAttribute : NSFontAttributeName value : font range : range];
   [text addAttribute : NSForegroundColorAttributeName value : color range : range];
}

//________________________________________________________________________________________
- (void) addVersionInfo
{
   NSAttributedString * const caption = [[NSAttributedString alloc] initWithString : @"\nVersion:\n\n"];
   const NSRange captionRange = NSMakeRange(text.length, caption.length);
   NSString *version = (NSString *)[[[NSBundle mainBundle] infoDictionary] objectForKey : @"CFBundleShortVersionString"];
   if (!version)//Can this ever happen???
      version = @"Unknown";
   NSString *build = (NSString *)[[[NSBundle mainBundle] infoDictionary] objectForKey : @"CFBundleVersion"];
   if (!build)//Can this ever happen???
      build = @"unknown";
   version = [NSString stringWithFormat:@"\tCERN.app: v. %@, build %@\n", version, build];
   NSAttributedString * const versionInfo = [[NSAttributedString alloc] initWithString : version];
   const NSRange versionInfoRange = NSMakeRange(captionRange.location + captionRange.length, versionInfo.length);
   
   [text appendAttributedString : caption];
   [text appendAttributedString : versionInfo];

   //Let's do some nice formatting here!
   [self setCaptionAttribute : captionRange];
   //
   UIFont * const textFont = [UIFont fontWithName : @"PTSans-Caption" size : 14.f];
   [self setFont : textFont color : [UIColor blackColor] forRange : versionInfoRange];
}

//________________________________________________________________________________________
- (void) addDevelopersInfo
{
   //Info about developers can be, of course, read from a special file later :)
   NSAttributedString * const caption = [[NSAttributedString alloc] initWithString : @"\nDevelopers:\n\n"];
   const NSRange captionRange = NSMakeRange(text.length, caption.length);
   NSAttributedString * const developersInfo = [[NSAttributedString alloc] initWithString : @"\tEamon Ford,\n\tFons Rademakers,\n\tTimur Pocheptsov.\n"];
   const NSRange devInfoRange = NSMakeRange(captionRange.location + captionRange.length, developersInfo.length);
   
   [text appendAttributedString : caption];
   [text appendAttributedString : developersInfo];

   //Let's do some nice formatting here!
   [self setCaptionAttribute : captionRange];
   //
   UIFont * const textFont = [UIFont fontWithName : @"PTSans-Caption" size : 14.f];
   [self setFont : textFont color : [UIColor blackColor] forRange : devInfoRange];
}

//________________________________________________________________________________________
- (void) addReadabilityInfo
{
   NSAttributedString * const caption = [[NSAttributedString alloc] initWithString : @"\nReadability:\n\n"];
   const NSRange captionRange = NSMakeRange(text.length, caption.length);
   NSAttributedString * const readabilityInfo = [[NSAttributedString alloc] initWithString : @"\"READABILITY turns any web page into a clean view for "
                                                                                 "reading now or later on your computer, smartphone, or tablet.\" - "];
   const NSRange infoRange = NSMakeRange(captionRange.location + captionRange.length, readabilityInfo.length);
   NSAttributedString * const readabilityLink = [[NSAttributedString alloc] initWithString : @"www.readability.com\n"];
   const NSRange linkRange = NSMakeRange(infoRange.location + infoRange.length, readabilityLink.length);
   
   [text appendAttributedString : caption];
   [text appendAttributedString : readabilityInfo];
   [text appendAttributedString : readabilityLink];

   [self setCaptionAttribute : captionRange];

   UIFont * const textFont = [UIFont fontWithName : @"Helvetica" size : 14.f];
   [self setFont : textFont color : [UIColor blackColor] forRange : infoRange];

   [text addAttribute : NSForegroundColorAttributeName value : [UIColor blueColor] range : linkRange];
}

//________________________________________________________________________________________
- (void) addIconsInfo
{
   NSAttributedString * const caption = [[NSAttributedString alloc] initWithString : @"\nSocial networks' icons:\n\n"];
   const NSRange captionRange = NSMakeRange(text.length, caption.length);
   NSAttributedString * const link = [[NSAttributedString alloc] initWithString : @"Author: http://www.deleket.com/index.html\n"];
   const NSRange linkRange = NSMakeRange(captionRange.location + captionRange.length + 8, link.length - 8);
   NSAttributedString * const info = [[NSAttributedString alloc] initWithString : @"License: http://creativecommons.org/licenses/by-nc-nd/3.0/legalcode"];
   const NSRange infoRange = NSMakeRange(linkRange.location + linkRange.length + 9, info.length - 9);//+9 -9 == not to include 'License: '
   
   [text appendAttributedString : caption];
   [text appendAttributedString : link];
   [text appendAttributedString : info];
   
   [self setCaptionAttribute:captionRange];
   [text addAttribute : NSForegroundColorAttributeName value : [UIColor blueColor] range : linkRange];
   [text addAttribute : NSForegroundColorAttributeName value : [UIColor blueColor] range : infoRange];
}

//________________________________________________________________________________________
- (void) addComponentInfo : (NSString *) componentName licenseFile : (NSString *) fileName author : (NSString *) author
{
   assert(fileName != nil && "addComponentInfo:author:, parameter 'fileName' is nil");
   assert(author != nil && "addComponentInfo:author:, parameter 'author' is nil");

   NSAttributedString * const caption = [[NSAttributedString alloc] initWithString : componentName];
   const NSRange captionRange = NSMakeRange(text.length, caption.length);
   NSAttributedString * const authorInfo = [[NSAttributedString alloc] initWithString : [NSString stringWithFormat:@"\n\nAuthor: %@\n\n", author]];
   const NSRange infoRange = NSMakeRange(captionRange.location + captionRange.length, authorInfo.length);
   
   [text appendAttributedString : caption];
   [text appendAttributedString : authorInfo];

   [self setCaptionAttribute : captionRange];
   
   UIFont * const textFont = [UIFont fontWithName : @"Helvetica" size : 14.f];
   [self setFont : textFont color : [UIColor blackColor] forRange : infoRange];

   if (NSString * const filePath = [[NSBundle mainBundle] pathForResource : fileName ofType : @"txt"]) {
      NSError *error = nil;
      NSMutableString * const licenseText = [NSMutableString stringWithContentsOfURL : [NSURL fileURLWithPath : filePath] encoding : NSUTF8StringEncoding error : &error];
      if (!error) {
         [licenseText appendString : @"\n"];
         [text appendAttributedString : [[NSAttributedString alloc] initWithString : licenseText]];
         const NSRange licRange = NSMakeRange(infoRange.location + infoRange.length, licenseText.length);
         
         UIFont * const licFont = [UIFont fontWithName : @"Courier" size : 8.f];
         [self setFont:licFont color:[UIColor blackColor] forRange:licRange];
      }
   }
}

@end
