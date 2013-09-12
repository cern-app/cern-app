#import <cassert>

#import <UIKit/UIKit.h>

#import "DeviceCheck.h"

namespace CernAPP {

//________________________________________________________________________________________
bool SystemVersionEqualTo(NSString *version)
{
   assert(version != nil && "SystemVersionEqualTo, parameter 'version' is nil");

   return [[[UIDevice currentDevice] systemVersion] compare : version options : NSNumericSearch] == NSOrderedSame;
}

//________________________________________________________________________________________
bool SystemVersionGreaterThan(NSString *version)
{
   assert(version != nil && "SystemVersionGreaterThan, parameter 'version' is nil");

   return [[[UIDevice currentDevice] systemVersion] compare : version options : NSNumericSearch] == NSOrderedDescending;
}

//________________________________________________________________________________________
bool SystemVersionGreaterThanOrEqualTo(NSString *version)
{
   assert(version != nil && "SystemVersionGreaterThanOrEqualTo, parameter 'version' is nil");

   return [[[UIDevice currentDevice] systemVersion] compare : version options : NSNumericSearch] != NSOrderedAscending;
}

//________________________________________________________________________________________
bool SystemVersionLessThan(NSString *version)
{
   assert(version != nil && "SystemVersionLessThan, parameter 'version' is nil");
   
   return [[[UIDevice currentDevice] systemVersion] compare : version options : NSNumericSearch] == NSOrderedAscending;
}

//________________________________________________________________________________________
bool SystemVersionLessThanOrEqualTo(NSString *version)
{
   assert(version != nil && "SystemVersionLessThanOrEqualTo, parameter 'version' is nil");

   return [[[UIDevice currentDevice] systemVersion] compare : version options : NSNumericSearch] != NSOrderedDescending;
}

}
