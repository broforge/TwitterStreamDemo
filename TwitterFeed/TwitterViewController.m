//
//  TwitterViewController.m
//  TwitterFeed
//
//  Created by BrotoMan on 3/26/14.
//  Copyright (c) 2014 BrotoMan. All rights reserved.
//

#import "TwitterViewController.h"


#import "TwitterTableViewCell.h"
#import <Social/Social.h>
#import <Accounts/Accounts.h>

#define MAX_TWEETS 50

typedef enum{
    ConnectionStateNone = 0,
    ConnectionStateAuthorizing,
    ConnectionStateStreaming,
}ConnectionState;

static ACAccountStore* _store;

@interface TwitterViewController ()

@property (strong, nonatomic) NSMutableArray* array;
@property (strong, nonatomic) NSURLConnection* connection;
@property ConnectionState state;
@property (strong, nonatomic) NSMutableData* data;

@end

@implementation TwitterViewController

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if (_store == nil)
    {
        _store = [[ACAccountStore alloc] init];
    }
    
    self.state = ConnectionStateNone;
    self.array = [NSMutableArray arrayWithCapacity:MAX_TWEETS];
    self.data = [NSMutableData data];
    
    for (UIView* parent in self.searchBar.subviews)
    {
        for (UIView* child in parent.subviews)
        {
            if ([child isKindOfClass:[UITextField class]])
            {
                ((UITextField*)child).enablesReturnKeyAutomatically = NO;
                break;
            }
        }
    }
}

#pragma mark - Twitter Stream

- (void)startStreaming:(NSString*)searchKey
{
    [self.connection cancel];
    self.connection = nil;

    [self.array removeAllObjects];
    
    if (searchKey.length == 0)
    {
        self.state = ConnectionStateNone;
        [self.tableView reloadData];
        return;
    }
    else
    {
        self.state = ConnectionStateAuthorizing;
        [self.tableView reloadData];
    }
    
    ACAccountType *twitterAccountType = [_store accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    
    ACAccountStoreRequestAccessCompletionHandler handler = ^(BOOL granted, NSError *error)
    {
        if (granted)
        {
            NSArray *twitterAccounts = [_store accountsWithAccountType:twitterAccountType];
            if ([twitterAccounts count] > 0)
            {
                ACAccount *account = [twitterAccounts lastObject];
                
                if ([searchKey hasPrefix:@"@"])
                {
                    [self startUserIDRequest:searchKey withAccount:account];
                }
                else
                {
                    NSDictionary *params = @{@"track" : searchKey};
                    [self startTrackRequest:params withAccount:account];
                }
            }
        }
        else
        {
            NSLog(@"connection error: %@", [error localizedDescription]);
            
            self.state = ConnectionStateNone;
            [self.tableView reloadData];
        }
    };
    
    [_store requestAccessToAccountsWithType:twitterAccountType options:nil completion:handler];
}

- (void)startUserIDRequest:(NSString*)searchKey withAccount:(ACAccount*)account
{
    NSString* screenName = [searchKey stringByReplacingOccurrencesOfString:@"@" withString:@""];
    
    // request required replacing ',' with %2C
    screenName = [screenName stringByReplacingOccurrencesOfString:@"," withString:@"%2C"];
    
    NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.twitter.com/1/users/lookup.json?screen_name=%@",screenName]];
    SLRequest *request = [SLRequest requestForServiceType:SLServiceTypeTwitter
                                            requestMethod:SLRequestMethodGET
                                                      URL:url
                                               parameters:nil];
    request.account = account;
    
    [request performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
        if (!error && responseData.length > 0)
        {
            NSArray* parsedData = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:&error];
            
            NSMutableString* userList = [NSMutableString stringWithFormat:@""];
            for (NSDictionary* dictionary in parsedData)
            {
                if(userList.length > 0)
                {
                    // need to use ',' instead of %2C or twitter cannot parse the params
                    [userList appendString:@","];
                }
                [userList appendString:[dictionary objectForKey:@"id_str"]];
            }
            NSDictionary *params = @{@"follow" : userList};
            [self startTrackRequest:params withAccount:account];
        }
        else
        {
            NSLog(@"userID request error: %@", [error localizedDescription]);
            self.state = ConnectionStateNone;
            [self.tableView reloadData];
        }
    }];

}

- (void)startTrackRequest:(NSDictionary*)params withAccount:(ACAccount*)account
{
    NSURL *url = [NSURL URLWithString:@"https://stream.twitter.com/1.1/statuses/filter.json"];
    SLRequest *request = [SLRequest requestForServiceType:SLServiceTypeTwitter
                                            requestMethod:SLRequestMethodPOST
                                                      URL:url
                                               parameters:params];
    [request setAccount:account];
    
    dispatch_async(dispatch_get_main_queue(),
                   ^{
                       self.connection = [NSURLConnection connectionWithRequest:[request preparedURLRequest] delegate:self];
                       [self.connection start];
                   });
}

#pragma mark - NSURLConnection data delegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    NSLog(@"connection started");
    self.state = ConnectionStateStreaming;
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationFade];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    NSLog(@"data received");
    
    [self.data appendData:data];
    NSString* jsonString = [[NSString alloc] initWithData:self.data encoding:NSUTF8StringEncoding];
    self.data.length = 0;

    NSArray* jsonEntries = [jsonString componentsSeparatedByCharactersInSet: [NSCharacterSet newlineCharacterSet]];
    NSMutableArray* validEntries = [NSMutableArray array];
    for (NSString* entry in jsonEntries)
    {
        if (entry.length > 0)
        {
            [validEntries addObject:entry];
        }
    }
    
    NSData* partialEntryData = nil;
    for (NSString* entry in validEntries)
    {
        NSData* entryData = [entry dataUsingEncoding:NSUTF8StringEncoding];
        
        if (entryData)
        {
            NSError* error;
            NSDictionary *parsedObject = [NSJSONSerialization JSONObjectWithData:entryData options:0 error:&error];
            if (!error)
            {
                [self.array insertObject:parsedObject atIndex:0];
                if (self.array.count > MAX_TWEETS)
                {
                    [self.array removeLastObject];
                }
            }
            else
            {
                NSLog(@"parse error: %@", [error localizedDescription]);
                NSLog(@"dataString: %@", entry);

                if (entry.length > 0 && entry == [jsonEntries lastObject])
                {
                    partialEntryData = entryData;
                }
            }
        }
    }
    
    if (partialEntryData)
    {
        [self.data appendData:partialEntryData];
    }

    [self.tableView reloadData];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    NSLog(@"connection finished");
    
    self.connection = nil;
    self.state = ConnectionStateNone;
    [self.tableView reloadData];
}

#pragma mark - NSURLConnection delegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    NSLog(@"connection failed");
    
    self.connection = nil;
    self.state = ConnectionStateNone;
    [self.tableView reloadData];
}

#pragma mark - UISearchBar delegate

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [searchBar resignFirstResponder];
    [self startStreaming:searchBar.text];
}

#pragma mark - Table View data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.array count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    TwitterTableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    
    NSDictionary* info = [_array objectAtIndex:indexPath.row];
    cell.screenName.text = [[info objectForKey:@"user"]objectForKey:@"screen_name"];
    cell.tweet.text = [info objectForKey:@"text"];
    
    return cell;
}

#pragma mark - UITableView delegate

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (self.state == ConnectionStateAuthorizing)
    {
        UITableViewCell* header = [tableView dequeueReusableCellWithIdentifier:@"authorizingHeader"];
        return header.contentView;
    }
    else if (self.state == ConnectionStateStreaming)
    {
        UITableViewCell* header = [tableView dequeueReusableCellWithIdentifier:@"streamingHeader"];
        return header.contentView;
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (self.state != ConnectionStateNone)
    {
        return 45;
    }
    return 0;
}

#pragma mark - Actions

- (IBAction)screenTap:(id)sender
{
    [self.searchBar resignFirstResponder];
}

- (IBAction)cancelButtonClicked:(id)sender
{
    NSLog(@"connection canceled");
    
    [self.connection cancel];
    self.connection = nil;
    self.state = ConnectionStateNone;
    [self.tableView reloadData];
}

@end
