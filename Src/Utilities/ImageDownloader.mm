#import <cassert>

#import <UIKit/UIKit.h>

#import "ImageDownloader.h"

//
//Small and trivial class - wrapper for a NSURLConnection to
//download images (thumbnails and icons). Inspired by Apple's
//LazyTableImages code sample.
//

@implementation ImageDownloader {
   NSURLConnection *imageConnection;
   NSMutableData *imageData;
   NSURL *url;
   BOOL delayImageCreation;
}

@synthesize delegate, indexPathInTableView, image;

//________________________________________________________________________________________
- (id) initWithURLString : (NSString *) urlString
{
   assert(urlString != nil && "initWithURLString:, parameter 'url' is nil");
   
   if (self = [super init]) {
      url = [NSURL URLWithString : urlString];
      if (!url)
         return nil;//Funny, what will ARC do?

      imageData = nil;
      imageConnection = nil;
      delayImageCreation = NO;
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
      delayImageCreation = NO;
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
- (void) startDownload : (BOOL) createUIImage
{
   delayImageCreation = createUIImage;
   [self startDownload];
}

//________________________________________________________________________________________
- (void) createUIImage
{
   if (imageData && imageData.length) {
      image = [[UIImage alloc] initWithData : imageData];
      imageData = nil;
   }
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

   if (imageData.length && !delayImageCreation) {
      image = [[UIImage alloc] initWithData : imageData];
      imageData = nil;
   }
   
   [delegate imageDidLoad : indexPathInTableView];
}

@end

