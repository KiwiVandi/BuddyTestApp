//
//  BFBViewController.h
//  BuddyFBSample
//
//  Copyright (c) 2012 Buddy Platform, Inc. All rights reserved.
//  Code may be freely referenced and redistributed.
//

#import <UIKit/UIKit.h>
#import "FBConnect.h"

//#warning Same as above, but from Facebook Dev Site
#define kFacebookApplicationID		@"107221322757542"

@interface BFBViewController : UIViewController <FBSessionDelegate, FBRequestDelegate>

@property (strong, nonatomic) IBOutlet UIImageView	*profileImage;
@property (strong, nonatomic) IBOutlet UIImageView	*filteredImage;
@property (strong, nonatomic) IBOutlet UILabel		*nameLabel;
@property (strong, nonatomic) IBOutlet UILabel		*progressLabel;
@property (strong, nonatomic) IBOutlet UIButton		*bindUserButton;
@property (strong, nonatomic) IBOutlet UIButton		*processPictureButton;
@property (strong, nonatomic) IBOutlet UIButton		*logoutUserButton;

@property (strong, nonatomic) Facebook	*facebook;
@property (strong, nonatomic) NSString	*buddyToken;
@property (assign, nonatomic) NSInteger	fbRequestTag;

// Actions
- (IBAction)bindBuddyUser: (id)sender;
- (IBAction)processBuddyPicture: (id)sender;
- (IBAction)logoutBuddyUser: (id)sender;

// Support calls
- (void)setFBProfileImage: (NSString *)imgRef;
- (void)setFBSampleImage: (NSString *)imgRef;
- (void)setBuddyProfileImage: (NSString *)imgRef;
- (void)setBuddySampleImage: (NSString *)imgRef;
- (void)postOnFacebook: (NSString *)picURL;
- (void)refreshUI;

@end
