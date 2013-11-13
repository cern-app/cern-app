//
//  ArticleDetailViewController.h
//  CERN App
//
//  Created by Eamon Ford on 6/18/12.
//  Copyright (c) 2012 CERN. All rights reserved.
//

#import <MessageUI/MessageUI.h>
#import <UIKit/UIKit.h>

#import "ConnectionController.h"
#import "OverlayView.h"
#import "MWFeedItem.h"

@interface ArticleDetailViewController : UIViewController <UIWebViewDelegate, NSURLConnectionDelegate, NSURLConnectionDataDelegate,
                                                           OverlayViewDelegate, MFMailComposeViewControllerDelegate,
                                                           ConnectionController, UIScrollViewDelegate>

@property (nonatomic, strong) IBOutlet UIWebView *rdbView;
@property (nonatomic, strong) IBOutlet UIWebView *pageView;
@property (nonatomic, strong) IBOutlet UIView *containerView;

@property (nonatomic, strong) NSString *rdbCache;

@property (nonatomic, copy) NSString *articleID;
@property (nonatomic, copy) NSString *title;

@property (nonatomic) BOOL canUseReadability;

- (void) setContentForArticle : (MWFeedItem *) article;
//Setup view controller from the cached feed.
- (void) setLink : (NSString *) link title : (NSString *) title;

//We load controller in response to APN.
- (void) setSha1Link : (NSString *) link;

@end
