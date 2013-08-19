#import <cassert>

namespace CernAPP {
namespace TwitterAPI {

//________________________________________________________________________________________
inline NSString *ConsumerKey()
{
   assert(0 && "ConsumerKey, dummy version");
   return nil;
}

//________________________________________________________________________________________
inline NSString *ConsumerSecret()
{
   assert(0 && "ConsumerSecret, dummy version");
   return nil;
}

//________________________________________________________________________________________
inline NSString *OauthToken()
{
   assert(0 && "OauthToken, dummy version");
   return nil;
}

//________________________________________________________________________________________
inline NSString *OauthTokenSecret()
{
   assert(0 && "OauthTokenSecret, dummy version");
   return nil;
}

}

//I have to add the following definition here, since I do not want to have one more 'secret file'.
//TODO: create a special source file for this.

namespace Details {

//________________________________________________________________________________________
inline NSString *GetThumbnailURL(NSString *imageURL)
{
   //That's a dummy version which does nothing at all.
   return imageURL;
}

//________________________________________________________________________________________
inline NSString * GetAPNRegisterDeviceTokenRequest(NSString * /*deviceToken*/)
{
   //Noop.
   return nil;
}

}//namespace Details

}//namespace CernAPP
