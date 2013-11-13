#import <cassert>

#import <CommonCrypto/CommonCrypto.h>

#import "APNUtils.h"

namespace CernAPP {

//________________________________________________________________________________________
NSString *Sha1Hash(NSString *src)
{
   assert(src != nil && "Sha1Hash, parameter 'src' is nil");
   NSData * const data = [src dataUsingEncoding:NSUTF8StringEncoding];
   uint8_t digest[CC_SHA1_DIGEST_LENGTH] = {};

   CC_SHA1(data.bytes, data.length, digest);
   NSMutableString * const output = [NSMutableString stringWithCapacity : CC_SHA1_DIGEST_LENGTH * 2];
   for (unsigned i = 0; i < CC_SHA1_DIGEST_LENGTH; ++i)
      [output appendFormat : @"%02x", digest[i]];

   return output;
}

const NSUInteger apnHashSize = 40;
NSString * const apnHashKey = @"sha1";
NSString * const apnFeedKey = @"updated";

}
