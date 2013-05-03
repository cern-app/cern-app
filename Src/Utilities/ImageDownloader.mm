#import <cassert>

#import <UIKit/UIKit.h>

#import "ImageDownloader.h"

//
//Small and trivial class - wrapper for a NSURLConnection to
//download images (thumbnails and icons). Inspired by Apple's
//LazyTableImages code sample.
//

@implementation ImageDownloader {
   NSMutableData *imageData;
   NSURLConnection *imageConnection;
   NSURL *url;
}

@synthesize delegate, indexPathInTableView, image;

//________________________________________________________________________________________
- (id) initWithURLString : (NSString *) urlString
{
   assert(urlString != nil && "initWithURLString:, parameter 'url' is nil");
   
   if (self = [super init]) {
      url = [NSURL URLWithString : urlString];
      imageData = nil;
      imageConnection = nil;
   }
   
   return self;
}

//________________________________________________________________________________________
- (id) initWithURL : (NSURL *) anUrl
{
   assert(anUrl != nil && "initWithURL:, parameter 'url' is nil");
   
   if (self = [super init]) {
      url = anUrl;
      imageData = nil;
      imageConnection = nil;
   }
   
   return self;
}

//________________________________________________________________________________________
- (void) dealloc
{
   [self cancelDownload];
}

//________________________________________________________________________________________
- (void) startDownload
{
   assert(imageConnection == nil && "startDownload, download started already");

   image = nil;
   imageData = [[NSMutableData alloc] init];
   imageConnection = [[NSURLConnection alloc] initWithRequest : [NSURLRequest requestWithURL : url] delegate : self];
}

//________________________________________________________________________________________
- (void) cancelDownload
{
   if (imageConnection) {
      [imageConnection cancel];
      imageConnection = nil;
      imageData = nil;
   }
}

#pragma mark - NSURLConnectionDelegate

//________________________________________________________________________________________
- (void) connection : (NSURLConnection *) connection didReceiveData : (NSData *) data
{
   assert(connection != nil && "connection:didReceiveData:, parameter 'connection' is nil");
   assert(data != nil && "connection:didReceiveData:, parameter 'data' is nil");
   assert(imageData != nil && "connection:didReceiveData:, imageData is nil");
   
   if (connection != imageConnection) {
      //I do not think this can ever happen :)
      NSLog(@"imageDownloader, error: connection:didReceiveData:, data from unknown connection");
      return;
   }
   
   [imageData appendData : data];
}

//________________________________________________________________________________________
- (void) connection : (NSURLConnection *) connection didFailWithError : (NSError *) error
{
#pragma unused(error)

   assert(connection != nil && "connection:didFailWithError:, parameter 'connection' is nil");
   assert(delegate != nil && "connectionDidFaildWithError:, delegate is nil");

   if (connection != imageConnection) {
      //Can this ever happen?
      NSLog(@"imageDownloader, error: connection:didFaileWithError:, unknown connection");
      return;
   }

   imageData = nil;
   imageConnection = nil;
   
   assert(indexPathInTableView != nil &&
          "connection:didFailWithError:, indexPathInTableView is nl");

   [delegate imageDownloadFailed : indexPathInTableView];
}

//________________________________________________________________________________________
- (void) connectionDidFinishLoading : (NSURLConnection *) connection
{
   assert(connection != nil && "connectionDidFinishLoading:, parameter 'connection' is nil");
   assert(image == nil && "connectionDidFinishLoading:, image must be nil");
   assert(indexPathInTableView != nil && "connectionDidFinishLoading:, indexPathInTableView is nil");
   assert(delegate != nil && "connectionDidFinishLoadin:, delegate is nil");
   
   if (connection != imageConnection) {
      NSLog(@"imageDownloader, error: connectionDidFinishLoading:, unknown connection");
      return;
   }

   imageConnection = nil;

   if (imageData.length) {
      //Actually, it's not a bad idea for iPhone also, but it's just a test now.
      if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
         [self performSelectorInBackground : @selector(createUIImageInBackground) withObject : nil];
      } else  {
         image = [[UIImage alloc] initWithData : imageData];
         [delegate imageDidLoad : indexPathInTableView];
         imageData = nil;
      }
   }
}

//________________________________________________________________________________________
- (void) createUIImageInBackground
{
   assert(image == nil && "createUIImageInBackground, image must be nil");
   assert(imageData.length != 0 && "createUIImageInBackground, imageData is either nil or empty");
   
   image = [[UIImage alloc] initWithData : imageData];
   imageData = nil;
   [self performSelectorOnMainThread : @selector(informDelegate) withObject : nil waitUntilDone : NO];
}

//________________________________________________________________________________________
- (void) informDelegate
{
   assert(indexPathInTableView != nil && "informDelegate, indexPathIntableView is nil");
   assert(delegate != nil && "informDelegate, delegate is nil");
   
   [delegate imageDidLoad : indexPathInTableView];
}

@end

