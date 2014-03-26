//
//  TwitterViewController.h
//  TwitterFeed
//
//  Created by BrotoMan on 3/26/14.
//  Copyright (c) 2014 BrotoMan. All rights reserved.
//

#import "ViewController.h"

@interface TwitterViewController : UIViewController <UISearchBarDelegate, UITableViewDataSource, UITableViewDelegate>

@property (weak, nonatomic) IBOutlet UISearchBar *searchBar;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
- (IBAction)screenTap:(id)sender;
- (IBAction)cancelButtonClicked:(id)sender;

@end
