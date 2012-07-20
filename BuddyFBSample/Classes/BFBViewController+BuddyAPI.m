//
//  BFBViewController+BuddyAPI.m
//  BuddyFBSample
//
//  Copyright (c) 2012 Buddy Platform, Inc. All rights reserved.
//  Code may be freely referenced and redistributed.
//

#import "BFBViewController+BuddyAPI.h"
#import "Wrapper.h"
#import "NSString+MD5.h"

#define kBuddyServiceURL			@"http://webservice.buddyplatform.com/Service/v1/BuddyService.ashx"
//#warning Fill in these two values to the ones that match your app
#define kBuddyApplicationName		@"testbuddyapp"//@"#<Application Name>#"		// Get it from Buddy's site
#define kBuddyApplicationPassword	@"7EFA3E18-5179-4984-94D9-065E3B69A179"//@"#<Application Password>#"// Same as above

// The Buddy commands we're going to use
#define kCheckBuddyUser				@"UserAccount_Profile_CheckUserName"
#define kCreateBuddyUser			@"UserAccount_Profile_Create"
#define kRecoverBuddyUser			@"UserAccount_Profile_Recover"
#define kGetUserIDFromToken			@"UserAccount_Profile_GetUserIDFromUserToken"
#define kUserMetaDataSetValue		@"MetaData_UserMetaDataValue_Set"
#define kUserMetaDataGetValue		@"MetaData_UserMetaDataValue_Get"
#define kUserMetaDataDeleteValue	@"MetaData_UserMetaDataValue_Delete"
#define kProfilePictureAdd			@"Pictures_ProfilePhoto_Add"
#define kProfilePictureGet			@"Pictures_ProfilePhoto_GetMyList"
#define kPhotoAlbumCreate			@"Pictures_PhotoAlbum_Create"
#define kPhotoAlbumGetList			@"Pictures_PhotoAlbum_GetList"
#define kPhotoAlbumAdd				@"Pictures_Photo_Add"
#define kPhotoFilterApply			@"Pictures_Filters_ApplyFilter"
#define kPhotoGet					@"Pictures_Photo_Get"

@implementation BFBViewController (BuddyAPI)

/*
 * Create a new Buddy user, the name will be the same than the Facebook username,
 * and the password the hash of the account id
 */
- (void)createUser: (NSDictionary *)meDict
{
	Wrapper			*wrapper;
	NSDictionary	*params;
    
    NSLog(@"%@", meDict);
    
	// This isn't that safe, but here just as an example
	NSString		*pwdHash	= [[NSString stringWithFormat: @"BuddySalt%@", [meDict objectForKey: @"id"]] MD5];
	
	self.progressLabel.text	= @"Creating Buddy user…";
	
	wrapper	= [[Wrapper alloc] initWithBlock:^(Wrapper *wrapper, NSError *error) {
        
        NSLog(@"Reply");
        
		if (error) {
			NSLog(@"Create user on Buddy failed: %@", [error localizedDescription]);
			return;
		}
		
		// We got a reply back, check and get it as User Token
		NSString	*respText	= [wrapper responseAsText];
        
        NSLog(@"%@", respText);
        
		if ([respText hasPrefix: @"UT-"]) {
			self.buddyToken	= respText;
			[[NSUserDefaults standardUserDefaults] setObject: self.buddyToken forKey: @"BuddyUserToken"];
			[[NSUserDefaults standardUserDefaults] synchronize];
			
			[self getUserID: YES];
			
			[self refreshUI];
			
			self.nameLabel.text	= [meDict objectForKey: @"name"];
			[self setFBProfileImage: [meDict objectForKey: @"id"]];
			
			[self storeFacebookToken: [meDict objectForKey: @"name"]];
		}
	}];
	
	params	= [NSDictionary dictionaryWithObjectsAndKeys: kBuddyApplicationName, @"BuddyApplicationName",
													   kBuddyApplicationPassword, @"BuddyApplicationPassword",
													   [meDict objectForKey: @"username"], @"NewUserName",
													   pwdHash, @"UserSuppliedPassword",
													   [meDict objectForKey: @"gender"], @"NewUserGender",
													   @"", @"UserAge",
													   [meDict objectForKey: @"email"], @"NewUserEmail",
													   @"-1", @"StatusID",	
													   @"1", @"FuzzLocationEnabled",
													   @"0", @"CelebModeEnabled",
													   @"", @"ApplicationTag",
													   @"", @"RESERVED",		
													   nil];
	
	[wrapper sendRequestTo: kBuddyServiceURL
				 usingVerb: @"GET"
			withParameters: params
			   withAPIName: kCreateBuddyUser];
}

/*
 * Tries to recover an existing Buddy user, the name will be the same than the Facebook username,
 * and the password the hash of the account id, same as above with creation
 */
- (void)recoverUser: (NSDictionary *)meDict
{
	Wrapper			*wrapper;
	NSDictionary	*params;
	NSString		*pwdHash	= [[NSString stringWithFormat: @"BuddySalt%@", [meDict objectForKey: @"id"]] MD5];
	
	self.progressLabel.text	= @"Finding Buddy user…";
	
	wrapper	= [[Wrapper alloc] initWithBlock:^(Wrapper *wrapper, NSError *error) {
		if (error) {
			NSLog(@"Recover user on Buddy failed: %@", [error localizedDescription]);
			return;
		}
		
		// We got a reply back, check and get it as User Token
		NSString	*respText	= [wrapper responseAsText];
		if ([respText hasPrefix: @"UT-"]) {
			
			self.buddyToken	= respText;
			[[NSUserDefaults standardUserDefaults] setObject: self.buddyToken forKey: @"BuddyUserToken"];
			[[NSUserDefaults standardUserDefaults] synchronize];
			
			[self getUserID: NO];
			
			[self refreshUI];
			
			self.nameLabel.text	= [meDict objectForKey: @"name"];
			
			[self storeFacebookToken: [meDict objectForKey: @"name"]];
		}
	}];
	
	params	= [NSDictionary dictionaryWithObjectsAndKeys: kBuddyApplicationName, @"BuddyApplicationName",
													   kBuddyApplicationPassword, @"BuddyApplicationPassword",
													   [meDict objectForKey: @"username"], @"username",
													   pwdHash, @"usersuppliedpassword",
													   nil];
	
	[wrapper sendRequestTo: kBuddyServiceURL
				 usingVerb: @"GET"
			withParameters: params
			   withAPIName: kRecoverBuddyUser];
}

/*
 * Get the Buddy user ID, it's needed to handle Photo Albums,
 * if it's passed the new user flag, create a new album as well
 * otherwise just get the existing one
 */
- (void)getUserID: (BOOL)isNewUser
{
	Wrapper			*wrapper;
	NSDictionary	*params;
	
	self.progressLabel.text	= @"Getting Buddy user ID…";
	
	wrapper	= [[Wrapper alloc] initWithBlock:^(Wrapper *wrapper, NSError *error) {
		if (error) {
			NSLog(@"Getting user ID on Buddy failed: %@", [error localizedDescription]);
			return;
		}
		
		// Save it for later use
		[[NSUserDefaults standardUserDefaults] setObject: [wrapper responseAsText] forKey: @"BuddyUserID"];
		[[NSUserDefaults standardUserDefaults] synchronize];
		
		// Proceed to create or find a photo album
		if (isNewUser)
			[self createPhotoAlbum];
		else
			[self getPhotoAlbum];
	}];
	
	params	= [NSDictionary dictionaryWithObjectsAndKeys: kBuddyApplicationName, @"BuddyApplicationName",
													   kBuddyApplicationPassword, @"BuddyApplicationPassword",
													   self.buddyToken, @"UserToken",
													   @"", @"RESERVED",		
													   nil];
	
	[wrapper sendRequestTo: kBuddyServiceURL
				 usingVerb: @"GET"
			withParameters: params
			   withAPIName: kGetUserIDFromToken];
}

/*
 * Checks if a Buddy user with the same name exists already,
 * if it does just recover its user token, ID & album, otherwise create one
 */
- (void)checkAndBindUser: (NSDictionary *)meDict
{
	Wrapper			*wrapper;
	NSDictionary	*params;
	
	self.progressLabel.text	= @"Checking for Buddy user…";
	
	wrapper	= [[Wrapper alloc] initWithBlock:^(Wrapper *wrapper, NSError *error) {
		if (error) {
			NSLog(@"Check to Buddy failed: %@", [error localizedDescription]);
			return;
		}
		
		if ([[wrapper responseAsText] isEqualToString: @"UserNameAlreadyInUse"])
			[self recoverUser: meDict];
		else
			[self createUser: meDict];
	}];
	
	params	= [NSDictionary dictionaryWithObjectsAndKeys: kBuddyApplicationName, @"BuddyApplicationName",
													   kBuddyApplicationPassword, @"BuddyApplicationPassword",
													   [meDict objectForKey: @"username"], @"UserNameToVerify",
													   @"", @"RESERVED",		
													   nil];
	
	[wrapper sendRequestTo: kBuddyServiceURL
				 usingVerb: @"GET"
			withParameters: params
			   withAPIName: kCheckBuddyUser];
}

/*
 * Store Facebook's profile image as Buddy profile pict.
 */
- (void)storeBuddyProfileImage: (UIImage *)anImage
{
	Wrapper			*wrapper;
	NSDictionary	*params;
	
	self.progressLabel.text	= @"Storing Buddy profile image…";
	
	wrapper	= [[Wrapper alloc] initWithBlock:^(Wrapper *wrapper, NSError *error) {
		if (error) {
			NSLog(@"Set profile pic to Buddy failed: %@", [error localizedDescription]);
			return;
		}
		
		self.progressLabel.text	= nil;
	}];
	
	params	= [NSDictionary dictionaryWithObjectsAndKeys: kBuddyApplicationName, @"BuddyApplicationName",
													   kBuddyApplicationPassword, @"BuddyApplicationPassword",
													   self.buddyToken, @"UserToken",
													   UIImageJPEGRepresentation(anImage, 0.8), @"bytesFullPhotoData",
													   @"", @"ApplicationTag",
													   @"", @"RESERVED",		
													   nil];
	
	[wrapper sendRequestTo: kBuddyServiceURL
				 usingVerb: @"POST"
			withParameters: params
			   withAPIName: kProfilePictureAdd];
}

/*
 * Get Buddy's profile image (that should match Facebook's one).
 */
- (void)loadBuddyProfileImage
{
	Wrapper			*wrapper;
	NSDictionary	*params;
	
	self.progressLabel.text	= @"Loading Buddy profile image…";
	
	wrapper	= [[Wrapper alloc] initWithBlock:^(Wrapper *wrapper, NSError *error) {
		if (error) {
			NSLog(@"Load profilePic from Buddy failed: %@", [error localizedDescription]);
			return;
		}
		NSArray			*values	= [[wrapper responseAsObject] objectForKey: @"data"];
		NSDictionary	*mValue	= [values lastObject];
		
		// Load and show the pic in the UI
		if (mValue) {
			NSString		*pictURL	= [mValue objectForKey: @"fullPhotoURL"];
			
			[self setBuddyProfileImage: pictURL];
		}
	}];
	
	params	= [NSDictionary dictionaryWithObjectsAndKeys: kBuddyApplicationName, @"BuddyApplicationName",
													   kBuddyApplicationPassword, @"BuddyApplicationPassword",
													   self.buddyToken, @"UserToken",
													   nil];
	
	[wrapper sendRequestTo: kBuddyServiceURL
				 usingVerb: @"GET"
			withParameters: params
			   withAPIName: kProfilePictureGet];
}

/*
 * Store Facebook access token, expiration date and real name in User Metadata
 * This allows later access without the need to login again
 */
- (void)storeFacebookToken: (NSString *)aName
{
	Wrapper			*wrapper;
	NSDictionary	*params;
	NSString		*tokenStr	= [NSString stringWithFormat: @"%@|%.0f|%@",
															self.facebook.accessToken,
															[self.facebook.expirationDate timeIntervalSinceReferenceDate],
															aName];
	
	self.progressLabel.text	= @"Storing FB credentials into Buddy user…";
	
	wrapper	= [[Wrapper alloc] initWithBlock:^(Wrapper *wrapper, NSError *error) {
		if (error) {
			NSLog(@"Store FB data to Buddy failed: %@", [error localizedDescription]);
			return;
		}
		
		NSLog(@"Store FB data result: %@", [wrapper responseAsText]);
	}];
	
	params	= [NSDictionary dictionaryWithObjectsAndKeys: kBuddyApplicationName, @"BuddyApplicationName",
													   kBuddyApplicationPassword, @"BuddyApplicationPassword",
													   self.buddyToken, @"UserToken",
													   @"FBCredentials", @"MetaKey",
													   tokenStr, @"MetaValue",
													   [NSNumber numberWithFloat: 0.0], @"MetaLongitude",
													   [NSNumber numberWithFloat: 0.0], @"MetaLatitude",		
													   @"", @"ApplicationTag",
													   @"", @"RESERVED",		
													   nil];
	
	[wrapper sendRequestTo: kBuddyServiceURL
				 usingVerb: @"GET"
			withParameters: params
			   withAPIName: kUserMetaDataSetValue];
}

/*
 * Load back Facebook access token, expiration date and real name from User Metadata
 */
- (void)loadFacebookToken
{
	Wrapper			*wrapper;
	NSDictionary	*params;
	
	self.progressLabel.text	= @"Loading FB credentials from Buddy user…";
	
	wrapper	= [[Wrapper alloc] initWithBlock:^(Wrapper *wrapper, NSError *error) {
		if (error) {
			NSLog(@"Load FB data from Buddy failed: %@", [error localizedDescription]);
			return;
		}
		
		if ([[wrapper responseAsObject] isKindOfClass: [NSNull class]]) {
			NSLog(@"Load FB data returned a NULL object");
			return;
		}
		
		NSArray			*values	= [[wrapper responseAsObject] objectForKey: @"data"];
		NSDictionary	*mValue	= [values lastObject];
		
		if (mValue) {
			NSString		*tokenStr	= [mValue objectForKey: @"metaValue"];
			NSArray			*tokenArray	= [tokenStr componentsSeparatedByString: @"|"];
			
			if ([tokenArray count] >= 3) {
                self.facebook.accessToken		= [tokenArray objectAtIndex: 0];
                self.facebook.expirationDate	= [NSDate dateWithTimeIntervalSinceReferenceDate: [[tokenArray objectAtIndex:1] doubleValue]];
                self.nameLabel.text				= [tokenArray objectAtIndex: 2];
			}
			[self refreshUI];
		}
	}];
	
	params	= [NSDictionary dictionaryWithObjectsAndKeys: kBuddyApplicationName, @"BuddyApplicationName",
													   kBuddyApplicationPassword, @"BuddyApplicationPassword",
													   self.buddyToken, @"UserToken",
													   @"FBCredentials", @"MetaKey",
													   nil];
	
	[wrapper sendRequestTo: kBuddyServiceURL
				 usingVerb: @"GET"
			withParameters: params
			   withAPIName: kUserMetaDataGetValue];
}

/*
 * Delete Facebook access token, expiration date and real name from User Metadata
 * This happens when user logs out of Facebook
 */
- (void)deleteFacebookToken
{
	Wrapper			*wrapper;
	NSDictionary	*params;
	
	self.progressLabel.text	= @"Deleting FB credentials from Buddy user…";
	
	wrapper	= [[Wrapper alloc] initWithBlock:^(Wrapper *wrapper, NSError *error) {
		if (error) {
			NSLog(@"Delete FB data from Buddy failed: %@", [error localizedDescription]);
			return;
		}
		
		self.progressLabel.text	= nil;
		NSLog(@"Delete FB data result: %@", [wrapper responseAsText]);
	}];
	
	params	= [NSDictionary dictionaryWithObjectsAndKeys: kBuddyApplicationName, @"BuddyApplicationName",
													   kBuddyApplicationPassword, @"BuddyApplicationPassword",
													   self.buddyToken, @"UserToken",
													   @"FBCredentials", @"MetaKey",
													   nil];
	
	[wrapper sendRequestTo: kBuddyServiceURL
				 usingVerb: @"GET"
			withParameters: params
			   withAPIName: kUserMetaDataDeleteValue];
}

/*
 * Create a new public photo album, with name fixed at "MyAlbum":
 * we'll store pictures to filter and filtered there.
 */
- (void)createPhotoAlbum
{
	Wrapper			*wrapper;
	NSDictionary	*params;
	
	self.progressLabel.text	= @"Creating photo album for Buddy user…";
	
	wrapper	= [[Wrapper alloc] initWithBlock:^(Wrapper *wrapper, NSError *error) {
		if (error) {
			NSLog(@"Create album on Buddy failed: %@", [error localizedDescription]);
			return;
		}
		
		// Save the album ID for later use
		NSString	*respText	= [wrapper responseAsText];
		if ([respText integerValue] > 1) {
			[[NSUserDefaults standardUserDefaults] setInteger: [respText integerValue] forKey: @"BuddyPhotoAlbum"];
			[[NSUserDefaults standardUserDefaults] synchronize];
		}
	}];
	
	params	= [NSDictionary dictionaryWithObjectsAndKeys: kBuddyApplicationName, @"BuddyApplicationName",
													   kBuddyApplicationPassword, @"BuddyApplicationPassword",
													   self.buddyToken, @"UserToken",
													   @"MyAlbum", @"AlbumName",
													   [NSNumber numberWithInt: 1], @"PublicAlbumBit",
													   @"", @"ApplicationTag",
													   @"", @"RESERVED",		
													   nil];
	
	[wrapper sendRequestTo: kBuddyServiceURL
				 usingVerb: @"GET"
			withParameters: params
			   withAPIName: kPhotoAlbumCreate];
}

/*
 * Get the latest photo album from an existing user:
 * same as above, but called on a user recover.
 */
- (void)getPhotoAlbum
{
	Wrapper			*wrapper;
	NSDictionary	*params;
	NSUserDefaults	*ud		= [NSUserDefaults standardUserDefaults];
	
	self.progressLabel.text	= @"Finding photo album for Buddy user…";
	
	wrapper	= [[Wrapper alloc] initWithBlock:^(Wrapper *wrapper, NSError *error) {
		if (error) {
			NSLog(@"Loading album on Buddy failed: %@", [error localizedDescription]);
			return;
		}
		
		if ([[wrapper responseAsObject] isKindOfClass: [NSNull class]]) {
			NSLog(@"Loading album returned a NULL object");
			return;
		}
		
		// Save the album ID for later use
		NSArray			*values	= [[wrapper responseAsObject] objectForKey: @"data"];
		NSDictionary	*mValue	= [values lastObject];
		
		if (mValue) {
			NSInteger	albumID	= [[mValue objectForKey: @"albumID"] integerValue];
			
			[ud setInteger: albumID forKey: @"BuddyPhotoAlbum"];
			[ud synchronize];
			
			self.progressLabel.text	= nil;
		}
	}];
	
	params	= [NSDictionary dictionaryWithObjectsAndKeys: kBuddyApplicationName, @"BuddyApplicationName",
													   kBuddyApplicationPassword, @"BuddyApplicationPassword",
													   self.buddyToken, @"UserToken",
													   [ud objectForKey: @"BuddyUserID"], @"UserProfileID",
													   nil];
	
	[wrapper sendRequestTo: kBuddyServiceURL
				 usingVerb: @"GET"
			withParameters: params
			   withAPIName: kPhotoAlbumGetList];
}

/*
 * Store a photo into the user's album, whose ID we got from one of the calls above.
 * When it's done, call the filter on the returned ID
 */
- (void)storeBuddySampleImage: (UIImage *)anImage
{
	Wrapper			*wrapper;
	NSDictionary	*params;
	
	self.progressLabel.text	= @"Storing photo in album for Buddy user…";
	
	wrapper	= [[Wrapper alloc] initWithBlock:^(Wrapper *wrapper, NSError *error) {
		if (error) {
			NSLog(@"Add pic to Buddy failed: %@", [error localizedDescription]);
			return;
		}
		
		NSString	*respText	= [wrapper responseAsText];
		if ([respText integerValue] > 1) {
			[self filterBuddyImageWithID: [respText integerValue]];
		}
	}];
	
	params	= [NSDictionary dictionaryWithObjectsAndKeys: kBuddyApplicationName, @"BuddyApplicationName",
													   kBuddyApplicationPassword, @"BuddyApplicationPassword",
													   self.buddyToken, @"UserToken",
													   [[NSUserDefaults standardUserDefaults] objectForKey: @"BuddyPhotoAlbum"], @"AlbumID",
													   UIImageJPEGRepresentation(anImage, 0.8), @"bytesFullPhotoData",
													   @"A sample photo", @"PhotoComment",
													   [NSNumber numberWithFloat: 0.0], @"Longitude",
													   [NSNumber numberWithFloat: 0.0], @"Latitude",		
													   @"", @"RESERVED",		
													   nil];
	
	[wrapper sendRequestTo: kBuddyServiceURL
				 usingVerb: @"POST"
			withParameters: params
			   withAPIName: kPhotoAlbumAdd];
}

/*
 * Filter a photo into the user's album, whose ID was returned by our storage.
 * When it's done, call the load back on the returned ID
 */
- (void)filterBuddyImageWithID: (NSInteger)anImageID
{
	Wrapper			*wrapper;
	NSDictionary	*params;
	
	self.progressLabel.text	= @"Filtering photo in album for Buddy user…";
	
	wrapper	= [[Wrapper alloc] initWithBlock:^(Wrapper *wrapper, NSError *error) {
		if (error) {
			NSLog(@"Filter pic from Buddy failed: %@", [error localizedDescription]);
			return;
		}
		
		NSString	*respText	= [wrapper responseAsText];
		if ([respText integerValue] > 1) {
			[self loadBuddyImageWithID: [respText integerValue]];
		}
	}];
	
	params	= [NSDictionary dictionaryWithObjectsAndKeys: kBuddyApplicationName, @"BuddyApplicationName",
													   kBuddyApplicationPassword, @"BuddyApplicationPassword",
													   self.buddyToken, @"UserToken",
													   [NSNumber numberWithInteger: anImageID], @"ExistingPhotoID",
													   @"Malibu", @"FilterName",
													   [NSNumber numberWithBool: YES], @"ReplacePhoto",
													   @"", @"FilterParameters",		
													   nil];
	
	[wrapper sendRequestTo: kBuddyServiceURL
				 usingVerb: @"POST"
			withParameters: params
			   withAPIName: kPhotoFilterApply];
}

/*
 * Load a photo from user's Buddy album, whose ID was returned by the filter call.
 * When it's done, set it as image in the UI, and post the thumbnail on Facebook
 */
- (void)loadBuddyImageWithID: (NSInteger)anImageID
{
	Wrapper			*wrapper;
	NSDictionary	*params;
	NSUserDefaults	*ud		= [NSUserDefaults standardUserDefaults];
	
	self.progressLabel.text	= @"Loading photo in album for Buddy user…";
	
	wrapper	= [[Wrapper alloc] initWithBlock:^(Wrapper *wrapper, NSError *error) {
		if (error) {
			NSLog(@"Loading photo on Buddy failed: %@", [error localizedDescription]);
			return;
		}
		
		if ([[wrapper responseAsObject] isKindOfClass: [NSNull class]]) {
			NSLog(@"Loading photo returned a NULL object");
			return;
		}
		
		NSArray			*values	= [[wrapper responseAsObject] objectForKey: @"data"];
		NSDictionary	*mValue	= [values lastObject];
		
		if (mValue) {
			[self setBuddySampleImage: [mValue objectForKey: @"fullPhotoURL"]];
			[self postOnFacebook: [mValue objectForKey: @"thumbnailPhotoURL"]];
		}
	}];
	
	params	= [NSDictionary dictionaryWithObjectsAndKeys: kBuddyApplicationName, @"BuddyApplicationName",
													   kBuddyApplicationPassword, @"BuddyApplicationPassword",
													   self.buddyToken, @"UserToken",
													   [ud objectForKey: @"BuddyUserID"], @"UserProfileID",
													   [NSNumber numberWithInteger: anImageID], @"PhotoID",
													   nil];
	
	[wrapper sendRequestTo: kBuddyServiceURL
				 usingVerb: @"GET"
			withParameters: params
			   withAPIName: kPhotoGet];
}

@end
