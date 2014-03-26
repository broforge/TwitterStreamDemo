//
//  ViewController.m
//  TwitterFeed
//
//  Created by BrotoMan on 3/25/14.
//  Copyright (c) 2014 BrotoMan. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self performSelector:@selector(startSegue) withObject:nil afterDelay:2.5];
}

- (void)startSegue
{
    [self performSegueWithIdentifier:@"ShowTwitterView" sender:nil];
}

@end
