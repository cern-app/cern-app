#import <algorithm>
#import <cassert>

#import <UIKit/UIKit.h>

#import "ImageDownloader.h"

//
//Small and trivial class - wrapper for a NSURLConnection to
//download images (thumbnails and icons). Inspired by Apple's
//LazyTableImages code sample.
//

namespace {

//________________________________________________________________________________________
bool ImageIsNonProportional(const CGSize &imageSize)
{
   //The definition of non-proportional is quite arbitrary,
   //I simply do not want to touch/scale images, which has
   //a significant difference between width/height.
   
   const CGFloat ratio = 3;
   
   if (!imageSize.width || !imageSize.height)//TODO: better test with CGFloats?
      return true;
   
   if (imageSize.width / imageSize.height > ratio)
      return true;
   
   if (imageSize.height / imageSize.width > ratio)
      return true;
   
   return false;
}

}

@implementation ImageDownloader {
   NSURLConnection *imageConnection;
   NSMutableData *imageData;
   NSURL *url;
   BOOL delayImageCreation;
}

@synthesize delegate, indexPathInTableView, image, dataSizeLimit, downscaleToSize;

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
      
      dataSizeLimit = 0;
      downscaleToSize = 0.f;
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
      
      dataSizeLimit = 0;
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
- (void) createThumbnailImageScaledTo : (CGFloat) dimension
{
   assert(dimension > 0.f &&
          "createThumbnailImageScaledTo:, parameter 'dimension' must be positive");

   image = nil;
   
   if (imageData && imageData.length) {
      if (UIImage * const tempImage = [[UIImage alloc] initWithData : imageData]) {

      
         const CGSize imageSize = tempImage.size;
         //1. I downscale image only if both w and h are > dimension.
         //2. I do not downscale images, if w >> h or w << h. (it's not a shift :))
         if (imageSize.width > dimension && imageSize.height > dimension && !ImageIsNonProportional(imageSize)) {
            //Yes, I want the minimum dimension to fit into the downscaled size :)
            const CGFloat scale = dimension / std::min(imageSize.width, imageSize.height);
            const CGSize newSize = CGSizeMake(imageSize.width * scale, imageSize.height * scale);
            //neither a width nor a height can be 0.
            
            //TODO: the code below is a fugly hack for an image downscaling.
            //The original code was taken from: https://gist.github.com/benilovj/2009030,
            //but it does not work with some images: http://vocaro.com/trevor/blog/2009/10/12/resize-a-uiimage-the-right-way/  - aha-aha,
            //"right way" my ass (see comments and the reply by Matt).
            //Sure, this is not how real programmers solve their problems -
            //to be investigated and REALLY fixed.
            //But I have no time now to write an image processing library now.

            CGContextRef bitmapCtx = CGBitmapContextCreate(nullptr, newSize.width, newSize.height,
                                                           CGImageGetBitsPerComponent(tempImage.CGImage), 0,
                                                           CGImageGetColorSpace(tempImage.CGImage),
                                                           CGImageGetBitmapInfo(tempImage.CGImage));//This shit generates error messages :(
            if (!bitmapCtx) {
               if (CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB()) {
                  bitmapCtx = CGBitmapContextCreate(nullptr, newSize.width, newSize.height,
                                                    8, 4 * size_t(newSize.width),
                                                    colorSpace,
                                                    kCGImageAlphaPremultipliedFirst);
                  CGColorSpaceRelease(colorSpace);
               }
            }
            
            if (bitmapCtx) {
               CGContextSetInterpolationQuality(bitmapCtx, kCGInterpolationHigh);
               CGContextDrawImage(bitmapCtx, CGRectMake(0.f, 0.f, newSize.width, newSize.height), tempImage.CGImage);
               CGImageRef cgImage = CGBitmapContextCreateImage(bitmapCtx);
               if (cgImage) {
                  image = [UIImage imageWithCGImage : cgImage];
                  CGImageRelease(cgImage);
               }
               
               CGContextRelease(bitmapCtx);
            }
         }
   
         if (!image)
            image = tempImage;
      }

      imageData = nil;      
   }
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
   
   if (dataSizeLimit && imageData.length > dataSizeLimit) {
      assert(delegate != nil && "connetion:didReceiveData:, delegate is nil");
      assert(indexPathInTableView != nil && "connection:didReceiveData:, indexPathInTableView is nil");
      [self cancelDownload];
      [delegate imageDownloadFailed : indexPathInTableView];
   } else
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

   if (!delayImageCreation) {
      if (!downscaleToSize)
         [self createUIImage];
      else
         [self createThumbnailImageScaledTo : downscaleToSize];
   }
   
   [delegate imageDidLoad : indexPathInTableView];
}

@end

