//
//  BulletinViewCell.h
//  CERN
//
//  Created by Timur Pocheptsov on 1/17/13.
//  Copyright (c) 2013 CERN. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BulletinViewCell : UITableViewCell

@property (nonatomic) IBOutlet UILabel *cellLabel;

@end


@interface BackgroundView : UIView

@property (nonatomic) BOOL selectedView;

@end