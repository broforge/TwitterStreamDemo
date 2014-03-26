//
//  TwitterTableViewCell.h
//  TwitterFeed
//
//  Created by BrotoMan on 3/26/14.
//  Copyright (c) 2014 BrotoMan. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface TwitterTableViewCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UIView *background;
@property (weak, nonatomic) IBOutlet UILabel *screenName;
@property (weak, nonatomic) IBOutlet UILabel *tweet;

@end
