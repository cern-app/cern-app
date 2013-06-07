//
//  AppSettingsController.h
//  CERN
//
//  Created by Timur Pocheptsov on 2/14/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AppSettingsController : UIViewController {

   IBOutlet UIView *guiSettingsView;
   IBOutlet UIView *rdbSettingsView;
   IBOutlet UIView *twitterSettingsView;
   
   IBOutlet UISlider *guiFontSizeSlider;
   IBOutlet UISlider *rdbFontSizeSlider;
   IBOutlet UISwitch *twitterSwitch;

}

- (IBAction) guiFontSizeChanged : (UISlider *) sender;
- (IBAction) htmlFontSizeChanged : (UISlider *) sender;
- (IBAction) twitterSwitchAction : (UISwitch *) sender;

- (IBAction) donePressed : (id)sender;

@end
