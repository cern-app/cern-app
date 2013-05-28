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
   
   IBOutlet UISlider *guiFontSizeSlider;
   IBOutlet UISlider *rdbFontSizeSlider;

}

- (IBAction) guiFontSizeChanged : (UISlider *) sender;
- (IBAction) htmlFontSizeChanged : (UISlider *) sender;

- (IBAction) donePressed : (id)sender;

@end
