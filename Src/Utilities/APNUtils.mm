#import <cassert>

#import <CommonCrypto/CommonCrypto.h>

#import "MWFeedItem.h"
#import "APNUtils.h"

namespace CernAPP {

//________________________________________________________________________________________
NSString *Sha1Hash(NSString *src)
{
   //From: https://github.com/hypercrypt/NSString-Hashes/blob/master/NSString%2BHashes.m
   assert(src != nil && "Sha1Hash, parameter 'src' is nil");
   NSData * const data = [src dataUsingEncoding : NSUTF8StringEncoding];
   uint8_t digest[CC_SHA1_DIGEST_LENGTH] = {};

   CC_SHA1(data.bytes, (CC_LONG)data.length, digest);
   NSMutableString * const output = [NSMutableString stringWithCapacity : CC_SHA1_DIGEST_LENGTH * 2];
   for (unsigned i = 0; i < CC_SHA1_DIGEST_LENGTH; ++i)
      [output appendFormat : @"%02x", digest[i]];

   return output;
}

//________________________________________________________________________________________
bool FindItem(NSString *sha1Hash, NSArray *feedCache)
{
   assert(sha1Hash != nil && "FindItem, parameter 'sha1Hash' is nil");

   if (!feedCache || !feedCache.count)
      return false;
   
   assert([feedCache[0] isKindOfClass : [MWFeedItem class]] &&
          "FindItem, an MWFeedItem expected in a cache");
   
   for (MWFeedItem *item in feedCache) {
      assert(item.link != nil && "FindItem, an invalid MWFeedItem with a nil link");
      NSString * const itemHash = Sha1Hash(item.link);
      if ([itemHash isEqualToString : sha1Hash])
         return true;
   }
   
   return false;
}

//________________________________________________________________________________________
bool FindItem(NSString *sha1Hash, NSObject *cache)
{
   assert(sha1Hash != nil && "FindItem, parameter 'sha1Hash' is nil");

   if (!cache || ![cache isKindOfClass : [NSArray class]])
      return false;
   
   NSArray * const feedCache = (NSArray *)cache;
   if (!feedCache.count)
      return false;
   
   NSObject * const testObj = feedCache[0];
   if ([testObj isKindOfClass : [MWFeedItem class]]) {
      return FindItem(sha1Hash, feedCache);
      //It's just an array of feed's entries.
   } else if ([testObj isKindOfClass : [NSArray class]]) {
      //Probably, it's a bulletin with sorted items.
      for (NSArray *testArray in feedCache) {
         if (testArray.count && ![testArray[0] isKindOfClass : [MWFeedItem class]])
            return false;//Ooops, this chache is something unexpected!

         if (FindItem(sha1Hash, testArray))
            return true;
      }
   }

   return false;
}

//These constant should be the same as nd_v3.py/feed_parser.py are using.
const NSUInteger apnHashSize = 40;
NSString * const apnHashKey = @"sha1";
NSString * const apnFeedKey = @"updated";
NSString * const apnTitleKey = @"item title";
NSString * const apnUrlKey = @"item url";

}


