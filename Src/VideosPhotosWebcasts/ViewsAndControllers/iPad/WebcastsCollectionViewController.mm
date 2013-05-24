//
//  WebcastsViewController.m
//  CERN
//
//  Created by Timur Pocheptsov on 5/24/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <cassert>

#import "WebcastsCollectionViewController.h"
#import "ECSlidingViewController.h"

//________________________________________________________________________________________
@implementation WebcastsCollectionViewController {   
   IBOutlet UISegmentedControl *segmentedControl;
   
   //Now I need 3 parsers for 3 different feeds (it's possible that user switched between the
   //different segments and thus all of them are loading now.
   MWFeedParser *parsers[3];
   NSArray *feedData[3];
   NSMutableArray *feedDataTmp[3];

   BOOL viewDidAppear;
}

- (id) initWithCoder : (NSCoder *) aDecoder
{
   if (self = [super initWithCoder : aDecoder]) {
      for (NSUInteger i = 0; i < 3; ++i) {
         parsers[i] = nil;
         feedData[i] = nil;
         feedDataTmp[i] = nil;
      }

      viewDidAppear = NO;
   }
   
   return self;
}

//________________________________________________________________________________________
- (void) viewDidLoad
{
   [super viewDidLoad];
	// Do any additional setup after loading the view.
}

//________________________________________________________________________________________
- (void) viewDidAppear : (BOOL) animated
{
   [super viewDidAppear : animated];

   assert(parsers[0] != nil && parsers[1] != nil && parsers[2] != nil &&
          "viewDidAppear:, not all parsers/feeds are valid");
   
   if (!viewDidAppear) {
      viewDidAppear = YES;
      //Check, which segment is visible now.
      [self refresh : NO];
   }
}

//________________________________________________________________________________________
- (void) didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Other methods.

//________________________________________________________________________________________
- (void) setControllerData : (NSArray *) dataItems
{
   assert(dataItems != nil && "setControllerData:, parameter 'dataItems' is nil");
   //We have 3 segments, 3 views, we need 3 links.
   assert(dataItems.count == 3 && "setControllerData:, unexpected number of items");
   //
   for (id item in dataItems) {
      assert([item isKindOfClass : [NSDictionary class]] &&
             "setControllerData:, a data item has a wrong type");
      
      NSDictionary * const itemDict = (NSDictionary *)item;
      assert([itemDict[@"Category name"] isKindOfClass : [NSString class]] &&
             "setControllerData:, 'Category name' is not found or has a wrong type");
      
      NSString * const name = (NSString *)itemDict[@"Category name"];
      assert([itemDict[@"Url"] isKindOfClass : [NSString class]] &&
             "setControllerData:, 'Url' is not found or has a wrong type");
      NSString * const urlStr = (NSString *)itemDict[@"Url"];
      
      if ([name isEqualToString:@"Live"])
         parsers[0] = [[MWFeedParser alloc] initWithFeedURL : [NSURL URLWithString : urlStr]];
      else if ([name isEqualToString : @"Upcoming"])
         parsers[1] = [[MWFeedParser alloc] initWithFeedURL : [NSURL URLWithString : urlStr]];
      else if ([name isEqualToString : @"Recent"])
         parsers[2] = [[MWFeedParser alloc] initWithFeedURL : [NSURL URLWithString : urlStr]];
      else
         assert(0 && @"setControllerData:, unknown category name for a segment");
   }
   
   assert(parsers[0] != nil && parsers[1] != nil && parsers[2] != nil &&
          "setControllerData:, not all parsers/feeds are valid");
   

   for (NSUInteger i = 0; i < 3; ++i) {
      parsers[i].delegate = self;
      parsers[i].connectionType = ConnectionTypeAsynchronously;
   }
}

//________________________________________________________________________________________
- (void) refresh : (BOOL) selectedSegmentOnly
{
   assert(parsers[0] != nil && parsers[1] != nil && parsers[2] != nil &&
          "refresh:, not all parsers/feeds are valid");

   //Check internet reachability.
   
   [self cancelAllDownloaders : selectedSegmentOnly];
   [self stopParsing : selectedSegmentOnly];
   [self startParsing : selectedSegmentOnly];
   
   //Show spinners.
}

#pragma mark - Feed parsers and related methods.

//________________________________________________________________________________________
- (void) feedParser : (MWFeedParser *) feedParser didParseFeedItem:(MWFeedItem *) item
{
   assert(feedParser != nil && "feedParser:didParseFeedItem:, parameter 'feedParser' is nil");
   assert(item != nil && "feedParser:didParseFeedItem:, parameter 'item' is nil");

   NSMutableArray *data = nil;
   for (unsigned i = 0; i < 3; ++i) {
      if (feedParser == parsers[i]) {
         data = feedDataTmp[i];
         break;
      }
   }
   
   assert(data != nil && "feedParser:didParseFeedItem:, unknown parser");
   [data addObject : item];
}


//________________________________________________________________________________________
- (void) feedParser : (MWFeedParser *) feedParser didFailWithError : (NSError *) error
{
   assert(feedParser != nil && "feedParser:didFailWithError:, parameter 'feedParser' is nil");

   //TODO: show some information (alert or HUD).

   NSLog(@"error: %@", error);
}

//________________________________________________________________________________________
- (void) feedParserDidFinish : (MWFeedParser *) feedParser
{
   assert(feedParser != nil && "feedParserDidFinish:, parameter 'feedParser' is nil");
   
   //Stop the corresponding spinner and update the corresponding collection view.
   NSMutableArray *data = nil;
   unsigned feedN = 0;
   for (unsigned i = 0; i < 3; ++i) {
      if (feedParser == parsers[i]) {
         feedN = i;
         data = feedDataTmp[i];
         break;
      }
   }
   
   assert(data != nil && "feedParserDidFinish:, unknown parser");
   
   NSLog(@"start of feed %u:", feedN);
   for (MWFeedItem *item in data) {
      NSLog(@"link %@", item.link);
      NSLog(@"title %@", item.title);
      NSLog(@"summary %@", item.summary);
      NSLog(@"description %@", item.description);
   }
   NSLog(@"end of feed %u", feedN);
}

//________________________________________________________________________________________
- (void) startParsing : (BOOL) selectedSegmentOnly
{
   if (selectedSegmentOnly) {
      const NSInteger selected = segmentedControl.selectedSegmentIndex;
      assert(parsers[selected] != nil &&
             "startParsing:, parser for selected segment is nil");
      [parsers[selected] parse];
      feedDataTmp[selected] = [[NSMutableArray alloc] init];
   } else {
      assert(parsers[0] != nil && parsers[1] != nil && parsers[2] != nil &&
             "startParsing:, not all parsers/feeds are valid");
      //assert on the parsing been stopped?
      for (unsigned i = 0; i < 3; ++i) {
         feedDataTmp[i] = [[NSMutableArray alloc] init];
         [parsers[i] parse];
      }
   }
}

//________________________________________________________________________________________
- (void) stopParsing : (BOOL) selectedSegmentOnly
{
   if (selectedSegmentOnly) {
      const NSInteger selected = segmentedControl.selectedSegmentIndex;
      assert(parsers[selected] != nil &&
             "stopParsing:, parser for selected segment is nil");
      [parsers[selected] stopParsing];
   } else {
      assert(parsers[0] != nil && parsers[1] != nil && parsers[2] != nil &&
             "stopParsing:, not all parsers/feeds are valid");
      //assert on the parsing been stopped?
      for (unsigned i = 0; i < 3; ++i)
         [parsers[i] stopParsing];
   }
}

#pragma mark - Thumbnails download.

//________________________________________________________________________________________
- (void) imageDidLoad : (NSIndexPath *) indexPath
{
#pragma unused(indexPath)
}

//________________________________________________________________________________________
- (void) imageDownloadFailed:(NSIndexPath *)indexPath
{
#pragma unsued(indexPath)
}

#pragma mark - UI.

//________________________________________________________________________________________
- (IBAction) sectionSelected : (UISegmentedControl *) sender
{

}

//________________________________________________________________________________________
- (IBAction) revealMenu : (id) sender
{
#pragma unused(sender)
   [self.slidingViewController anchorTopViewTo : ECRight];
}

//________________________________________________________________________________________
- (IBAction) reload : (id) sender
{

}

#pragma mark - ConnectionController

- (void) cancelAllDownloaders : (BOOL) selectedSegmentOnly
{
}

- (void) cancelAnyConnections
{
}

@end
