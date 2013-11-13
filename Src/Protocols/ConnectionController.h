//
//  ConnectionController.h
//  CERN
//
//  Created by Timur Pocheptsov on 1/17/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol ConnectionController <NSObject>
@required
- (void) cancelAnyConnections;
@end

namespace CernAPP {

void CancelConnections(UIViewController *controller);

}