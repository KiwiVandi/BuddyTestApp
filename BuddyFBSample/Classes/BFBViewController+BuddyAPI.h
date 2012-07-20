//
//  BFBViewController+BuddyAPI.h
//  BuddyFBSample
//
//  Copyright (c) 2012 Buddy Platform, Inc. All rights reserved.
//  Code may be freely referenced and redistributed.
//

#import "BFBViewController.h"

@interface BFBViewController (BuddyAPI)

- (void)createUser: (NSDictionary *)meDict;
- (void)recoverUser: (NSDictionary *)meDict;
- (void)getUserID: (BOOL)isNewUser;
- (void)checkAndBindUser: (NSDictionary *)meDict;
- (void)storeBuddyProfileImage: (UIImage *)anImage;
- (void)loadBuddyProfileImage;
- (void)storeFacebookToken: (NSString *)aName;
- (void)loadFacebookToken;
- (void)deleteFacebookToken;
- (void)createPhotoAlbum;
- (void)getPhotoAlbum;
- (void)storeBuddySampleImage: (UIImage *)anImage;
- (void)filterBuddyImageWithID: (NSInteger)anImageID;
- (void)loadBuddyImageWithID: (NSInteger)anImageID;

@end
