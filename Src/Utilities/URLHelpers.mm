#import "URLHelpers.h"
#import "MWFeedItem.h"

namespace CernAPP {

//________________________________________________________________________________________
NSString *FindUnescapedImageURLStringInHTMLString(NSString *htmlString)
{
   //This trick/code is taken from the v.1 of our app.
   //Author - Eamon Ford (with my modifications).

   if (!htmlString)
      return nil;
   
   NSScanner * const theScanner = [NSScanner scannerWithString : htmlString];
   //Find the start of IMG tag
   [theScanner scanUpToString : @"<img" intoString : nil];
   
   if (![theScanner isAtEnd]) {
      [theScanner scanUpToString : @"src" intoString : nil];
      NSCharacterSet * const charset = [NSCharacterSet characterSetWithCharactersInString : @"\"'"];
      [theScanner scanUpToCharactersFromSet : charset intoString : nil];
      [theScanner scanCharactersFromSet : charset intoString : nil];
      NSString *urlString = nil;
      [theScanner scanUpToCharactersFromSet : charset intoString : &urlString];
      // "url" now contains the URL of the img
      return urlString;
   }
   
   return nil;
}

//________________________________________________________________________________________
NSString *FindImageURLStringInHTMLString(NSString *htmlString)
{
   if (!htmlString)
      return nil;

   NSString * const urlString = FindUnescapedImageURLStringInHTMLString(htmlString);
   if (urlString)
      return [urlString stringByAddingPercentEscapesUsingEncoding : NSUTF8StringEncoding];

   //No (valid) img url was found.
   return nil;
}

//________________________________________________________________________________________
NSURL *FindImageURLInHTMLString(NSString *htmlString)
{
   if (NSString * const urlString = FindImageURLStringInHTMLString(htmlString))
      return [NSURL URLWithString : urlString];//Still can be nil.
   
   return nil;
}

//________________________________________________________________________________________
NSString *FindUnescapedImageURLStringInEnclosures(MWFeedItem *article)
{
   //Now we have some feeds with enclosures and this enclosures contains images
   //for feed's entries.
   assert(article != nil && "FindUnescapedImageURLStringInEnclosures, parameter 'article' is nil");
   
   if (!article.enclosures)
      return nil;

   for (id arrayItem in article.enclosures) {
      if ([arrayItem isKindOfClass : [NSDictionary class]]) {
         NSDictionary * const dict = (NSDictionary *)arrayItem;
         id val = nil;
         if ((val = dict[@"type"]) && [val isKindOfClass : [NSString class]]) {
            NSString * const enclosureType = [(NSString *)val lowercaseString];
            if (enclosureType.length) {
               if ([enclosureType rangeOfString:@"image/"].location != NSNotFound) {
                  id url = nil;
                  if ((url = dict[@"url"]) && [url isKindOfClass : [NSString class]])
                     return (NSString *)url;
               }
            }
         }
      }
   }

   return nil;
}

//________________________________________________________________________________________
NSString *FindImageURLStringInEnclosures(MWFeedItem *article)
{
   //Now we have some feeds with enclosures and this enclosures contains images
   //for feed's entries.
   assert(article != nil && "FindImageURLStringInEnclosures, parameter 'article' is nil");
   
   if (NSString * const urlString = FindUnescapedImageURLStringInEnclosures(article))
      return [urlString stringByAddingPercentEscapesUsingEncoding : NSUTF8StringEncoding];
   
   return nil;
}

//________________________________________________________________________________________
NSURL *FindImageURLInEnclosures(MWFeedItem *article)
{
   //Now we have some feeds with enclosures and this enclosures contains images
   //for feed's entries.
   assert(article != nil && "FindImageURLInEnclosures, parameter 'article' is nil");
   
   if (NSString * const urlString = FindImageURLStringInEnclosures(article))
      return [NSURL URLWithString : urlString];
   
   return nil;
}

//________________________________________________________________________________________
bool SkipReadabilityProcessing(NSString *url)
{
    //An ad-hoc solution to avoid "cleaning" some pages.
    //TODO: Add other type of links to exclude or find a better solution :)
    return [url hasPrefix:@"http://www.youtube.com/watch?"];
}

}
