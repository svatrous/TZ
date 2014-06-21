//
//  ViewController.h
//  Anybody here?
//
//  Created by Паша on 17.06.14.
//  Copyright (c) 2014 svatorus. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Parse/Parse.h>
#include "OpenUDID.h"

@interface ViewController : UIViewController
@property (weak,   nonatomic) IBOutlet UITableView             *tableView;
@property (weak,   nonatomic) IBOutlet UIButton             *onlineButton;

@property                              BOOL                      isOnline;
@property (strong, nonatomic)          NSMutableArray   *onlineUsersArray;
@property (strong, nonatomic)          NSString                 *objectID;
@property (weak, nonatomic) IBOutlet UIImageView *hiddenImage;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (weak, nonatomic) IBOutlet UILabel *timeLabel;
@property (strong, nonatomic) NSTimer *timer;
@property (strong, nonatomic) NSNumber *time;
@property (strong, nonatomic) UILocalNotification *notification;


- (IBAction)changeStatusAction:(id)sender;

@end
