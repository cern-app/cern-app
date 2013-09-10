#import <Foundation/Foundation.h>

@protocol APNEnabledController <NSObject>
@required

@property (nonatomic) NSUInteger apnID;
- (void) addAPNItems : (NSUInteger) newItems;

@end
