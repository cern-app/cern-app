//
//  AppSettingsController.m
//  CERN
//
//  Created by Timur Pocheptsov on 2/14/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <cassert>

#import <QuartzCore/QuartzCore.h>

#import "AppSettingsController.h"
#import "AppDelegate.h"

using CernAPP::TwitterFeedShowOption;

@implementation AppSettingsController

//________________________________________________________________________________________
- (void) defaultsChanged : (NSNotification *) notification
{
   if ([notification.object isKindOfClass : [NSUserDefaults class]]) {
      NSUserDefaults * const defaults = (NSUserDefaults *)notification.object;
      float sz = [defaults floatForKey : CernAPP::htmlBodyFontSizeKey];
      [rdbFontSizeSlider setValue : sz];

      sz = [defaults floatForKey : CernAPP::guiFontSizeKey];
      [guiFontSizeSlider setValue : sz];

      AppDelegate * const appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
      twitterSwitch.on = BOOL(appDelegate.tweetOption);
   }
}

//________________________________________________________________________________________
- (id) initWithNibName : (NSString *) nibNameOrNil bundle : (NSBundle *) nibBundleOrNil
{
   if (self = [super initWithNibName : nibNameOrNil bundle : nibBundleOrNil]) {

   }

   return self;
}

//________________________________________________________________________________________
- (void) dealloc
{
   [[NSNotificationCenter defaultCenter] removeObserver : self];
}

//________________________________________________________________________________________
- (void) viewDidLoad
{
   [super viewDidLoad];
   
	// Do any additional setup after loading the view.
   guiSettingsView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent : 0.5f];
   guiSettingsView.layer.cornerRadius = 10.f;
   
   rdbSettingsView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent : 0.5f];
   rdbSettingsView.layer.cornerRadius = 10.f;
   
   twitterSettingsView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent : 0.5f];
   twitterSettingsView.layer.cornerRadius = 10.f;

   NSUserDefaults * const defaults = [NSUserDefaults standardUserDefaults];

   //Read defaults for the sliders.
   float sz = [defaults floatForKey : CernAPP::guiFontSizeKey];
   [guiFontSizeSlider setValue : sz];

   sz = [defaults floatForKey : CernAPP::htmlBodyFontSizeKey];
   [rdbFontSizeSlider setValue : sz];

   BOOL twopt = [defaults boolForKey: CernAPP::tweetViewKey];
   twitterSwitch.on = twopt;

   if (![[UIApplication sharedApplication] canOpenURL : [NSURL URLWithString : @"twitter://"]]) {
      twitterSettingsView.hidden = YES;   //no need in this option, no external app to open tweets
      AppDelegate * const appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
      appDelegate.tweetOption = TwitterFeedShowOption::builtinView;
      [defaults setBool: BOOL(appDelegate.tweetOption) forKey : CernAPP::tweetViewKey];
      [defaults synchronize];
   }

   [[NSNotificationCenter defaultCenter] addObserver : self selector : @selector(defaultsChanged:) name : NSUserDefaultsDidChangeNotification object : nil];
}

//________________________________________________________________________________________
- (void) didReceiveMemoryWarning
{
   [super didReceiveMemoryWarning];
   // Dispose of any resources that can be recreated.
}

#pragma mark - GUI events.

//_______________________________________________________________________________________
- (IBAction) donePressed : (id)sender
{
   [self dismissViewControllerAnimated : YES completion : nil];
}

//_______________________________________________________________________________________
- (IBAction) guiFontSizeChanged : (UISlider *) sender
{
   assert(sender != nil && "guiFontSizeChanged:, parameter 'sender' is nil");

   [[NSUserDefaults standardUserDefaults] setFloat : sender.value forKey : CernAPP::guiFontSizeKey];
   [[NSUserDefaults standardUserDefaults] synchronize];
}

//________________________________________________________________________________________
- (IBAction) htmlFontSizeChanged : (UISlider *) sender
{
   assert(sender != nil && "htmlFontSizeChanged:, parameter 'sender' is nil");
   
   [[NSUserDefaults standardUserDefaults] setFloat : sender.value forKey : CernAPP::htmlBodyFontSizeKey];
   [[NSUserDefaults standardUserDefaults] synchronize];
}

//________________________________________________________________________________________
- (IBAction) twitterSwitchAction : (UISwitch *) sender
{
   assert(sender != nil && "twitterSwitchAction:, parameter 'sender' is nil");
   
   assert([[UIApplication sharedApplication].delegate isKindOfClass:[AppDelegate class]] &&
          "twitterSwitchAction:, application delegate has a wrong type");

   AppDelegate * const appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
   
   sender.isOn ? appDelegate.tweetOption = TwitterFeedShowOption::builtinView :
                 appDelegate.tweetOption = TwitterFeedShowOption::externalView;

   [[NSUserDefaults standardUserDefaults] setBool : BOOL(appDelegate.tweetOption) forKey : CernAPP::tweetViewKey];
   [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - Interface orientation.

//________________________________________________________________________________________
- (BOOL) shouldAutorotate
{
   return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
}

@end
