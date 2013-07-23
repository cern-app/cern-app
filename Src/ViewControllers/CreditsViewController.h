//
//  CreditsViewController.h
//  CERN
//
//  Created by Timur Pocheptsov on 2/15/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CreditsViewController : UIViewController {

IBOutlet UITextView *textView;

//I need this outlet, since the nav bar is in a storyboard and not
//accessible via navigation controller (we do not have one, "credits"
//view/controller is modal).
IBOutlet UINavigationBar *navigationBar;

}

- (IBAction) donePressed : (id) sender;

@end
