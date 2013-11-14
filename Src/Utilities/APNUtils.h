#import <Foundation/Foundation.h>

namespace CernAPP
{

NSString *Sha1Hash(NSString *src);

//APN payload "format" - keys into apn dictionary:
extern const NSUInteger apnHashSize;
extern NSString * const apnHashKey;
extern NSString * const apnFeedKey;
extern NSString * const apnTitleKey;
extern NSString * const apnUrlKey;


}
