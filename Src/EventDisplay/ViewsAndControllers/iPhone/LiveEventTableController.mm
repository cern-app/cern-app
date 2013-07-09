//
//  LiveEventTableController.m
//  CERN
//
//  Created by Timur Pocheptsov on 11/30/12.
//  Copyright (c) 2012 CERN. All rights reserved.
//

#import <cassert>

#import "LiveEventTableController.h"
#import "ECSlidingViewController.h"
#import "ApplicationErrors.h"
#import "NewsTableViewCell.h"
#import "ContentProviders.h"
#import "Reachability.h"

using CernAPP::NetworkStatus;

@implementation LiveEventTableController {
   unsigned tableEntryToLoad;
   unsigned flatRowIndex;

   NSURLConnection *connection;
   NSMutableData *imageData;
   NSString *sourceName;
   NSArray *tableData;
   BOOL refreshing;
   
   BOOL firstViewDidAppear;
   
   Reachability *internetReach;
}

@synthesize provider, navController;

//________________________________________________________________________________________
- (void) reachabilityStatusChanged : (Reachability *) current
{
   #pragma unused(current)
      
   if (internetReach && [internetReach currentReachabilityStatus] == NetworkStatus::notReachable) {
      if (refreshing) {
         [connection cancel];
         connection = nil;
         imageData = nil;
         [self.refreshControl endRefreshing];

         CernAPP::ShowErrorAlert(@"Please, check network!", @"Close");
         refreshing = NO;
      }
   }
}

//________________________________________________________________________________________
- (bool) hasConnection
{
   return [internetReach currentReachabilityStatus] != NetworkStatus::notReachable;
}

//________________________________________________________________________________________
+ (NSString *) nameKey
{
   return @"ImageName";
}

//________________________________________________________________________________________
+ (NSString *) urlKey
{
   return @"Url";
}

#pragma mark - Initialization.

//________________________________________________________________________________________
- (id) initWithStyle : (UITableViewStyle) style
{
   if (self = [super initWithStyle : style]) {
      firstViewDidAppear = YES;
   }

   return self;
}

//________________________________________________________________________________________
- (void) dealloc
{
   [internetReach stopNotifier];
   [[NSNotificationCenter defaultCenter] removeObserver : self];
}

//________________________________________________________________________________________
- (void) setTableContents : (NSArray *) contents experimentName : (NSString *)name
{
   assert(contents != nil && "setTableContents:, parameter 'contents' is nil");
   assert(name != nil && "setTableContents:, parameter 'name' is nil");

   tableData = contents;
   sourceName = name;
   tableEntryToLoad = 0;
   flatRowIndex = 0;
   refreshing = NO;
}

//________________________________________________________________________________________
- (void) viewDidLoad
{
   [super viewDidLoad];
   self.refreshControl = [[UIRefreshControl alloc] init];
   [self.refreshControl addTarget : self action : @selector(reloadFromRefreshControl) forControlEvents : UIControlEventValueChanged];
   
   [[NSNotificationCenter defaultCenter] addObserver : self selector : @selector(reachabilityStatusChanged:) name : CernAPP::reachabilityChangedNotification object : nil];
   internetReach = [Reachability reachabilityForInternetConnection];
   [internetReach startNotifier];
   [self reachabilityStatusChanged : internetReach];
   
   if ([self.navigationItem.title rangeOfString : @"Live Events"].location != NSNotFound)//Otherwise, name is too long.
      self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle : @"Events" style : UIBarButtonItemStylePlain target : nil action : nil];
   else if ([self.navigationItem.title rangeOfString : @"Status"].location != NSNotFound)//Otherwise, name is too long.
      self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle : @"Status" style : UIBarButtonItemStylePlain target : nil action : nil];
   
   [self.tableView registerClass : [NewsTableViewCell class] forCellReuseIdentifier : [NewsTableViewCell cellReuseIdentifier]];
}

//________________________________________________________________________________________
- (void) viewDidAppear : (BOOL)animated
{
   [super viewDidAppear : animated];

   if (!firstViewDidAppear) {
      firstViewDidAppear = YES;
      [self refresh];
   }

}

#pragma mark - Aux. function to search image data for a given row index.

//________________________________________________________________________________________
- (LiveImageData *) imageDataForFlatIndex : (NSInteger) row
{
   //As we can have nested sub-images in a tableData, described in nested NSArrays,
   //it's quite ugly and terribly inefficient to search for an image data. Fortunately, this code
   //is not supposed to work with huge image data sets, we have a special views/controllers
   //for such a sets. In our case, most probably we have only one nested NSArray if any at all
   //(and this NSArray is the only entry in the tableData).

   assert(row >= 0 && "imageDataForFlatIndex:, parameter 'row' must be non-negative");
   assert(tableData && [tableData count] && "imageDataForFlatIndex:, tableData is either nil or empty");

   LiveImageData *liveData = nil;
   
   NSInteger currentIndex = 0;
   for (id obj in tableData) {
      if ([obj isKindOfClass : [LiveImageData class]]) {
         if (currentIndex == row) {
            //We got our data
            liveData = (LiveImageData *)obj;
            break;
         } else
            ++currentIndex;
      } else {
         //First, it can be ONLY NSArray (NSMutableArray).
         assert([obj isKindOfClass : [NSArray class]] &&
                "tableView:cellForRowAtIndexPath:, item of unknown type");
         NSArray * const array = (NSArray *)obj;
         const NSInteger nSubImages = [array count];
         if (row <= currentIndex + nSubImages) {
            //The image data is in this nested array.
            id base = [array objectAtIndex : row - currentIndex];
            assert([base isKindOfClass : [LiveImageData class]]);
            liveData = (LiveImageData *)base;
            break;
         } else
            currentIndex += nSubImages;
      }
   }
   
   assert(liveData != nil && "imageDataForFlatIndex:, index is out of bounds");
   return liveData;
}

#pragma mark - Data management.

//________________________________________________________________________________________
- (void) refresh
{
   //Here we start loading images one by one, asynchronously (next load only started after the
   //previous finished of failed). Nothing is changed except images and probably dates.
   
   if (refreshing)
      return;
   
   if ([tableData count] && [self hasConnection]) {
      refreshing = YES;
   
      if (connection)
         [connection cancel];

      [self.tableView reloadData];

      tableEntryToLoad = 0;
      flatRowIndex = 0;
      LiveImageData *liveImageData = [self imageDataForFlatIndex : 0];
      NSURL * const url = [[NSURL alloc] initWithString : liveImageData.url];
      imageData = [[NSMutableData alloc] init];
      connection = [[NSURLConnection alloc] initWithRequest : [NSURLRequest requestWithURL : url] delegate : self];
   }
}

//________________________________________________________________________________________
- (void) reloadFromRefreshControl
{
   if (![self hasConnection]) {
      [self.refreshControl endRefreshing];
      CernAPP::ShowErrorAlert(@"Please, check network!", @"Close");
   } else
      [self refresh];
}

//________________________________________________________________________________________
- (void) didReceiveMemoryWarning
{
   [super didReceiveMemoryWarning];
}

//________________________________________________________________________________________
- (void) continueLoadImages
{
   assert(tableData && [tableData count] && "continueLoadFrom:, tableData is either nil or empty");
   assert(tableEntryToLoad < [tableData count] && "continueLoadFrom:, entry to load is out of bounds");
   
   LiveImageData *nextImageLiveData = nil;
   
   id base = [tableData objectAtIndex : tableEntryToLoad];
   
   if ([base isKindOfClass : [LiveImageData class]])
      nextImageLiveData = (LiveImageData *)base;
   else {
      assert([base isKindOfClass : [NSArray class]] &&
             "connectionDidFinishLoading:, unknown object");
      NSArray * const imageSet = (NSArray *)base;
      assert([imageSet count] && "connectionDidFinishLoading:, empty image set");
      nextImageLiveData = (LiveImageData *)[imageSet objectAtIndex : 0];
   }
   
   assert(nextImageLiveData != nil && "continueLoadFrom:, no data for next image found");
   
   NSURL * const url = [[NSURL alloc] initWithString : nextImageLiveData.url];
   imageData = [[NSMutableData alloc] init];
   connection = [[NSURLConnection alloc] initWithRequest : [NSURLRequest requestWithURL : url] delegate : self];
}

#pragma mark - Table view data source

//________________________________________________________________________________________
- (NSInteger) numberOfSectionsInTableView : (UITableView *) tableView
{
   // Return the number of sections.
   return 1;
}

//________________________________________________________________________________________
- (NSInteger) tableView : (UITableView *) tableView numberOfRowsInSection : (NSInteger) section
{
//   return [tableData count];//even if tableData is nil, this will be 0.
   assert(tableData != nil && "tableView:numberOfRowsInSection:, tableData is nil");
   
   NSInteger nRows = 0;
   for (id imageDesc in tableData) {
      if ([imageDesc isKindOfClass : [LiveImageData class]])
         ++nRows;
      else {
         assert([imageDesc isKindOfClass : [NSArray class]] &&
                "tableView:numberOfRowsInSection:, unexpected object in contentProviders");
         nRows += [(NSArray *)imageDesc count];
      }
   }
   
   return nRows;
   
}

//________________________________________________________________________________________
- (UITableViewCell *) tableView : (UITableView *) tableView cellForRowAtIndexPath : (NSIndexPath *) indexPath
{
   //Find feed item first.
   assert(indexPath.row >= 0 && "tableView:cellForRowAtIndexPath:, indexPath.row is negative");
   LiveImageData * const liveData = [self imageDataForFlatIndex : indexPath.row];
   assert(liveData != nil && "tableView:cellForRowAtIndexPath:, indexPath.row is out of bounds");

   UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier : [NewsTableViewCell cellReuseIdentifier]];
   assert((!cell || [cell isKindOfClass : [NewsTableViewCell class]]) &&
          "tableView:cellForRowAtIndexPath:, reusable cell has a wrong type");
   
   if (!cell)
      cell = [[NewsTableViewCell alloc] initWithFrame : [NewsTableViewCell defaultCellFrame]];

   [(NewsTableViewCell *)cell setCellData : liveData.imageName source : sourceName image : liveData.image imageOnTheRight : (indexPath.row % 4) == 3];

   return cell;
}

//________________________________________________________________________________________
- (CGFloat) tableView : (UITableView *) tableView heightForRowAtIndexPath : (NSIndexPath *) indexPath
{
   const NSInteger row = indexPath.row;
   assert(row >= 0 && "tableView:heightForRowAtIndexPath:, indexPath.row is negative");

   LiveImageData * const liveData = [self imageDataForFlatIndex : row];
   assert(liveData != nil && "tableView:heightForRowAtIndexPath:, indexPath.row is out of bounds");

   return [NewsTableViewCell calculateCellHeightForText : liveData.imageName source : sourceName image : liveData.image imageOnTheRight : (indexPath.row % 4) == 3];
}

#pragma mark - Table view delegate

//________________________________________________________________________________________
- (void) tableView : (UITableView *) tableView didSelectRowAtIndexPath : (NSIndexPath *) indexPath
{
   assert(provider != nil && "tableView:didSelectRowAtIndexPath:, provider is nil");
   assert(navController != nil && "tableView:didSelectRowAtIndexPath:, navController is nil");

   [self.tableView deselectRowAtIndexPath : indexPath animated : NO];
   [provider pushEventDisplayInto : navController selectedImage : indexPath.row];
}

#pragma mark - NSURLConnection delegate

//________________________________________________________________________________________
- (void) connection : (NSURLConnection *) urlConnection didReceiveData : (NSData *)data
{
   assert(urlConnection != nil && "connection:didReceiveData:, parameter 'connection' is nil");
   
   if (urlConnection != connection) {//Connection was cancelled.
      //This is not possible, but sometimes .. I have crashes and also search google about this.
      NSLog(@"connection:didReceiveData: was called for a cancelled connection");
      return;
   }

   assert(imageData != nil && "connection:didReceiveData:, imageData is nil");

   [imageData appendData : data];
}

//________________________________________________________________________________________
- (void) connectionDidFinishLoading : (NSURLConnection *) urlConnection
{
   assert(imageData != nil && "connectionDidFinishLoading:, imageData is nil");
   assert(tableData != nil && [tableData count] && "connectionDidFinishLoading:, tableData is either nil or empty");
   assert(tableEntryToLoad < [tableData count] && "connectionDidFinishLoading:, tableEntryToLoad is out of bounds");

   assert(urlConnection != nil && "connectionDidFinishLoading:, parameter 'urlConnection' is nil");

   if (urlConnection != connection) {//Connection was cancelled.
      //This is not possible, but sometimes .. I have crashes and also search google about this.
      NSLog(@"connectionDidFinishLoading: was called for a cancelled connection");
      return;
   }


   //Woo-hoo! We've got an image!(??)
   UIImage *newImage = nil;
   if ([imageData length])
      newImage = [UIImage imageWithData : imageData];
   
   id obj = [tableData objectAtIndex : tableEntryToLoad];
      
   if ([obj isKindOfClass : [LiveImageData class]]) {
      //We've just finished loading a single image.
      if (newImage) {
         LiveImageData * const liveData = (LiveImageData *)obj;
         liveData.image = newImage;
         //Reload a table's row.
         const NSUInteger path[2] = {0, flatRowIndex};//Row to update in a table view.
         NSIndexPath * const indexPath = [NSIndexPath indexPathWithIndexes : path length : 2];
         NSArray * const indexPaths = [NSArray arrayWithObject : indexPath];
         [self.tableView reloadRowsAtIndexPaths : indexPaths withRowAnimation : UITableViewRowAnimationNone];
      }

      ++flatRowIndex;
   } else {
      assert([obj isKindOfClass : [NSArray class]] && "connectionDidFinishLoading:, unknown object");
      NSArray * const imageSet = (NSArray *)obj;

      //We finished loading an image, which must be divided into sub-images.
      assert([imageSet count] && "connectionDidFinishLoading:, image set is empty");
      
      if (newImage) {
         //Now we have to cut sub-images.
         NSMutableArray * const rowsToUpdate = [[NSMutableArray alloc] init];

         unsigned currentRow = flatRowIndex;
         
         for (LiveImageData *liveData in imageSet) {
            //Strange, that UIImage does not have a ctor from another UIImage and rect.
            //So we need all this gymnastics.
            CGImageRef imageRef(CGImageCreateWithImageInRect(newImage.CGImage, liveData.bounds));
            if (imageRef) {
               liveData.image = [UIImage imageWithCGImage : imageRef];
               CGImageRelease(imageRef);
               
               const NSUInteger path[2] = {0, currentRow};//Row to update in a table view.
               NSIndexPath * const indexPath = [NSIndexPath indexPathWithIndexes : path length : 2];
               [rowsToUpdate addObject : indexPath];
            }
            
            ++currentRow;
         }
         
         if ([rowsToUpdate count])
            [self.tableView reloadRowsAtIndexPaths : rowsToUpdate withRowAnimation : UITableViewRowAnimationNone];

         flatRowIndex += [imageSet count];
      }
   }
   
   ++tableEntryToLoad;

   if (tableEntryToLoad < [tableData count]) {
      //Continue.
      [self continueLoadImages];
   } else {
      imageData = nil;
      connection = nil;
      [self.refreshControl endRefreshing];
      refreshing = NO;
   }
}

//________________________________________________________________________________________
- (void) connection : (NSURLConnection *) urlConnection didFailWithError : (NSError *) error
{
#pragma unused(error)

   assert(urlConnection != nil && "connection:didFailWithError:, parameter 'urlConnection' is nil");
   
   if (urlConnection != connection) {//Connection was cancelled.
      //This is not possible, but sometimes .. I have crashes and also search google about this.
      NSLog(@"connection:didFailWithError: was called for a cancelled connection");
      return;
   }

   assert(tableData != nil && [tableData count] && "connection:didFailWithError:, tableData is either nil or empty");
   assert(tableEntryToLoad < [tableData count] && "connection:didFailWithError:, imageToLoad index is out of bounds");
   
   ++tableEntryToLoad;
   
   if (tableEntryToLoad < [tableData count]) {
      id base = [tableData objectAtIndex : tableEntryToLoad];
      if ([base isKindOfClass : [LiveImageData class]])
         ++flatRowIndex;
      else {
         assert([base isKindOfClass : [NSArray class]] &&
                "connection:didFailWithError:, unknown object");
         flatRowIndex += [(NSArray *)base count];
      }
      
      [self continueLoadImages];
   } else {
      imageData = nil;
      connection = nil;
      flatRowIndex = 0;
      tableEntryToLoad = 0;
      [self.refreshControl endRefreshing];
      refreshing = NO;
   }   
}

#pragma mark - Hack to remove empty rows

//________________________________________________________________________________________
- (UIView *) tableView : (UITableView *) tableView viewForFooterInSection : (NSInteger) section
{
   //Many thanks to J. Costa for this trick. (http://stackoverflow.com/questions/1369831/eliminate-extra-separators-below-uitableview-in-iphone-sdk)
   if (!section)
      return [[UIView alloc] init];

   return nil;
}


#pragma mark - Sliding view.

//________________________________________________________________________________________
- (void) revealMenu : (id) sender
{
#pragma unused(sender)
   [self.slidingViewController anchorTopViewTo : ECRight];
}

#pragma mark - Connection controller.
//________________________________________________________________________________________
- (void) cancelAnyConnections
{
   if (connection) {
      [connection cancel];
      connection = nil;
   }
}

#pragma mark - Interface rotation.

//________________________________________________________________________________________
- (BOOL) shouldAutorotate
{
   return NO;
}

//________________________________________________________________________________________
- (NSUInteger) supportedInterfaceOrientations
{
   return  UIInterfaceOrientationMaskPortrait;
}

@end
