#import <Foundation/Foundation.h>

namespace CernAPP {

bool SystemVersionEqualTo(NSString *version);
bool SystemVersionGreaterThan(NSString *version);
bool SystemVersionGreaterThanOrEqualTo(NSString *version);
bool SystemVersionLessThan(NSString *version);
bool SystemVersionLessThanOrEqualTo(NSString *version);

}