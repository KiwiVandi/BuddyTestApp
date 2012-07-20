//
//  BFBAppDelegate.h
//  BuddyFBSample
//
//  Copyright (c) 2012 Buddy Platform, Inc. All rights reserved.
//  Code may be freely referenced and redistributed.
//

#import <UIKit/UIKit.h>
#import "FBConnect.h"

@class BFBViewController;

@interface BFBAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) BFBViewController *viewController;

@end
