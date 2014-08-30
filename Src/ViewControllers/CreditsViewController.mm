//
//  CreditsViewController.m
//  CERN
//
//  Created by Timur Pocheptsov on 2/15/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <cassert>

#import "CreditsViewController.h"
#import "DeviceCheck.h"

namespace {

//________________________________________________________________________________________
CGFloat CaptionFontSize()
{
   return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone ? 20.f : 26.f;
}

//________________________________________________________________________________________
CGFloat GenericTextFontSize()
{
   return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone ? 14.f : 24.f;
}

CGFloat LicenseFontSize()
{
   return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone ? 8.f : 18.f;
}

}

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
- (void) viewWillAppear : (BOOL) animated
{
   [super viewWillAppear : animated];
   
   if (CernAPP::SystemVersionGreaterThanOrEqualTo(@"7.0")) {
      if (UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation) &&
         UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
            self.navigationController.navigationBar.hidden = YES;
      }
   }
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
   UIFont * const titleFont = [UIFont fontWithName : @"PTSans-Bold" size : CaptionFontSize()];
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
      version = @"unknown";
   NSString *build = (NSString *)[[[NSBundle mainBundle] infoDictionary] objectForKey : @"CFBundleVersion"];
   if (!build)//Can this ever happen???
      build = @"unknown";
   version = [NSString stringWithFormat:@"\tCERN.app version: %@ (b%@)\n", version, build];
   NSAttributedString * const versionInfo = [[NSAttributedString alloc] initWithString : version];
   const NSRange versionInfoRange = NSMakeRange(captionRange.location + captionRange.length, versionInfo.length);
   
   [text appendAttributedString : caption];
   [text appendAttributedString : versionInfo];

   //Let's do some nice formatting here!
   [self setCaptionAttribute : captionRange];
   //
   UIFont * const textFont = [UIFont fontWithName : @"PTSans-Caption" size : GenericTextFontSize()];
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
   UIFont * const textFont = [UIFont fontWithName : @"PTSans-Caption" size : GenericTextFontSize()];
   [self setFont : textFont color : [UIColor blackColor] forRange : devInfoRange];
}

//________________________________________________________________________________________
- (void) addReadabilityInfo
{
   NSAttributedString * const caption = [[NSAttributedString alloc] initWithString : @"\nReadability:\n\n"];
   const NSRange captionRange = NSMakeRange(text.length, caption.length);
   NSAttributedString * const readabilityInfo = [[NSAttributedString alloc] initWithString :
                                                 @"\"READABILITY turns any web page into a clean view for "
                                                 "reading now or later on your computer, smartphone, or tablet.\" - "];
   const NSRange infoRange = NSMakeRange(captionRange.location + captionRange.length, readabilityInfo.length);
   NSAttributedString * const readabilityLink = [[NSAttributedString alloc] initWithString : @"www.readability.com\n"];
   const NSRange linkRange = NSMakeRange(infoRange.location + infoRange.length, readabilityLink.length);
   
   [text appendAttributedString : caption];
   [text appendAttributedString : readabilityInfo];
   [text appendAttributedString : readabilityLink];

   [self setCaptionAttribute : captionRange];

   UIFont * const textFont = [UIFont fontWithName : @"Helvetica" size : GenericTextFontSize()];
   [self setFont : textFont color : [UIColor blackColor] forRange : infoRange];

   [text addAttribute : NSForegroundColorAttributeName value : [UIColor blueColor] range : linkRange];
}

#pragma mark - Interface orientation change.

//________________________________________________________________________________________
- (BOOL) shouldAutorotate
{
   return YES;
}

//________________________________________________________________________________________
- (void) willRotateToInterfaceOrientation : (UIInterfaceOrientation) toInterfaceOrientation duration : (NSTimeInterval) duration
{
#pragma unused(duration)

   if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
      return;//We do not hide a navigation bar on iPad.
   
   if (CernAPP::SystemVersionGreaterThanOrEqualTo(@"7.0")) {
      if (UIInterfaceOrientationIsLandscape(toInterfaceOrientation)) {
         self.navigationController.navigationBar.hidden = YES;
      } else {
         self.navigationController.navigationBar.hidden = NO;
      }
   } else {
      const CGRect barFrame = navigationBar.frame;
      CGRect textFrame = textView.frame;

      if (UIInterfaceOrientationIsLandscape(toInterfaceOrientation)) {
         navigationBar.hidden = YES;
         textFrame.origin.y -= barFrame.size.height;
         textFrame.size.height += barFrame.size.height;
      } else {
         navigationBar.hidden = NO;
         textFrame.origin.y += barFrame.size.height;
         textFrame.size.height -= barFrame.size.height;
      }

      textView.frame = textFrame;
   }
}

@end
