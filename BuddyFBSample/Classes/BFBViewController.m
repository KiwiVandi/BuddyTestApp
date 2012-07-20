//
//  BFBViewController.m
//  BuddyFBSample
//
//  Copyright (c) 2012 Buddy Platform, Inc. All rights reserved.
//  Code may be freely referenced and redistributed.
//

#import "BFBViewController.h"
#import "BFBViewController+BuddyAPI.h"
#import "UIImageView+WebCache.h"

// Facebook APIs tags, to detect what we're up to
#define kMeRequestTag			10
#define kAlbumsRequestTag		20
#define kPhotosRequestTag		30
#define kPostRequestTag			40

@interface BFBViewController ()

@end

@implementation BFBViewController

@synthesize profileImage;
@synthesize filteredImage;
@synthesize nameLabel;
@synthesize progressLabel;
@synthesize bindUserButton;
@synthesize processPictureButton;
@synthesize logoutUserButton;

@synthesize facebook		= _facebook;
@synthesize buddyToken		= _buddyToken;
@synthesize fbRequestTag	= _fbRequestTag;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Initialize the Facebook instance, if it wasn't
    if (!self.facebook)
        self.facebook	= [[Facebook alloc] initWithAppId: kFacebookApplicationID
                                              andDelegate: self];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	
    self.buddyToken	= [[NSUserDefaults standardUserDefaults] objectForKey: @"BuddyUserToken"];
	
	[self refreshUI];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return UIInterfaceOrientationIsPortrait(interfaceOrientation);
}

#pragma mark - Actions

- (IBAction)bindBuddyUser: (id)sender
{
	// If we don't have a Buddy Token yet, use FB to login
	NSArray	*permissions	= [NSArray arrayWithObjects: @"user_about_me", @"email", @"read_stream",
														@"publish_stream", @"user_photos", nil];
	
	[self.facebook authorize: permissions];
}

- (IBAction)processBuddyPicture: (id)sender
{
	// Start the process of getting a picture from
	// a user Facebook album: list all albums first
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible: YES];
	
	self.fbRequestTag		= kAlbumsRequestTag;
	
	self.progressLabel.text	= @"Loading Facebook albums…";
	
	[self.facebook requestWithGraphPath: @"me/albums" andDelegate: self];
}

- (IBAction)logoutBuddyUser: (id)sender
{
	NSUserDefaults	*ud	= [NSUserDefaults standardUserDefaults];
	
	// Logout from Facebook first
	[self.facebook logout: self];
	
	// Remove everything , and cleanup Buddy Token
	self.buddyToken	= nil;
	
	[ud removeObjectForKey: @"BuddyUserToken"];
	[ud removeObjectForKey: @"BuddyUserID"];
	[ud removeObjectForKey: @"BuddyPhotoAlbum"];
	[ud synchronize];
	
	self.profileImage.image		= nil;
	self.filteredImage.image	= nil;
	self.nameLabel.text			= nil;
	self.progressLabel.text		= nil;
	
	[self refreshUI];
}

- (void)setFBProfileImage: (NSString *)imgRef
{
	// Get Facebook profile image asynchronously, based on the user ID
	// When done, store as profile image on Buddy
	NSString			*imageURL	= [NSString stringWithFormat: @"http://graph.facebook.com/%@/picture?type=large", imgRef];
	__weak UIImageView	*profImage	= self.profileImage;
	
	self.progressLabel.text	= @"Loading profile image…";
	
	[profImage setImageWithURL: [NSURL URLWithString: imageURL]
			  placeholderImage: nil
					   options: SDWebImageProgressiveDownload
					   success: ^(UIImage *image) {
						   [self storeBuddyProfileImage: image];
					   }
					   failure: ^(NSError *error) {
					   }];
}

- (void)setFBSampleImage: (NSString *)imgRef
{
	// Download and show the image we've chosen from Facebook Album,
	// when ready upload it to Buddy
	__weak UIImageView	*sampleImage	= self.filteredImage;
	
	self.progressLabel.text	= @"Loading sample image…";
	
	[sampleImage setImageWithURL: [NSURL URLWithString: imgRef]
				placeholderImage: nil
						 options: SDWebImageProgressiveDownload
						 success: ^(UIImage *image) {
							 [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible: NO];
							 [self storeBuddySampleImage: image];
						 }
						 failure: ^(NSError *error) {
						 }];
}

- (void)setBuddyProfileImage: (NSString *)imgRef
{
	// Download and show Buddy profile image
	// It should match Facebook's (until someone changes one of the two)
	self.progressLabel.text	= nil;
	
	[self.profileImage setImageWithURL: [NSURL URLWithString: imgRef]
					  placeholderImage: nil];
}

- (void)setBuddySampleImage: (NSString *)imgRef
{
	// Download and show Buddy filtered image
	// We're posting the thumbnail to the user's wall
	[self.filteredImage setImageWithURL: [NSURL URLWithString: imgRef]
					   placeholderImage: nil
								options: SDWebImageProgressiveDownload
								success: ^(UIImage *image) {
									self.progressLabel.text	= nil;
								}
								failure: ^(NSError *error) {
								}];
}

- (void)postOnFacebook: (NSString *)picURL
{
	// Make a call to the user's stream to publish the thumbnail's URL
	// We don't post the full image as there are limitations to
	// the size that Facebook accepts on the wall / feed
	NSMutableDictionary	*params	= [NSMutableDictionary dictionaryWithObjectsAndKeys:
																@"http://www.buddy.com", @"link",
																@"Buddy - Your cloud backend", @"name",
																@"A photo filtered by Buddy!", @"caption",
																@"I've used Buddy Platform to filter my photo from Facebook",  @"description",
																picURL, @"picture",
																nil];
	
	self.fbRequestTag	= kPostRequestTag;
	
	[self.facebook requestWithGraphPath: @"/me/feed"
							  andParams: params
						  andHttpMethod: @"POST"
							andDelegate: self];
}

- (void)refreshUI
{
	// Buddy token exist, get FB token back
	if (self.buddyToken) {
		// Enable UI
		self.bindUserButton.enabled			= NO;
		self.processPictureButton.enabled	= YES;
		self.logoutUserButton.enabled		= YES;
		
		// Set profile picture
		[self loadBuddyProfileImage];
		
		if (![self.facebook isSessionValid]) {
			// Recover from Buddy metadata, to complete
			// the connection to Facebook
			[self loadFacebookToken];
		}
	} else {
		// Disable UI
		self.bindUserButton.enabled			= YES;
		self.processPictureButton.enabled	= NO;
		self.logoutUserButton.enabled		= NO;
	}
}

#pragma mark - FBSessionDelegate

- (void)fbDidLogin
{
	// Request info on the current user
	self.fbRequestTag	= kMeRequestTag;
	
	[self.facebook requestWithGraphPath: @"me" andDelegate: self];
}

- (void)fbDidNotLogin: (BOOL)cancelled
{
}

- (void) fbDidLogout
{
    // Remove saved authorization from Buddy if it exists
	[self deleteFacebookToken];
}

- (void)fbDidExtendToken:(NSString*)accessToken
               expiresAt:(NSDate*)expiresAt
{
	self.facebook.accessToken		= accessToken;
	self.facebook.expirationDate	= expiresAt;
	
	// Save new metadata to Buddy
	[self storeFacebookToken: self.nameLabel.text];
}

- (void)fbSessionInvalidated
{
	[self fbDidLogout];
}

#pragma mark - FBRequestDelegate

- (void)request:(FBRequest *)request didLoad:(id)result
{
    NSLog(@"R did load");
	switch (self.fbRequestTag) {
		case kMeRequestTag:
			// Received user info, bind it to Buddy
			[self checkAndBindUser: result];
			break;
			
		case kAlbumsRequestTag:
			{
				// Received info on user's albums, get the first (if any) and ask for photos
				NSArray		*dataList	= [result objectForKey: @"data"];
				
                NSLog(@"%@", dataList);
                
				if ([dataList count]) {
					NSString	*objId		= [[dataList objectAtIndex: 0] objectForKey: @"id"];
					
                    NSLog(@"%@", objId);
                    
					self.progressLabel.text	= @"Loading Facebook photos…";
					
					self.fbRequestTag	= kPhotosRequestTag;
					
					[self.facebook requestWithGraphPath: [NSString stringWithFormat: @"%@/photos", objId]
											andDelegate: self];
				}
			}
			break;
			
		case kPhotosRequestTag:
			{
				// Received info on album's photos, get the first (if any) and set it for process
				NSArray		*dataList	= [result objectForKey: @"data"];
				
				if ([dataList count]) {
					NSArray		*imageList	= [[dataList objectAtIndex: 0] objectForKey: @"images"];
					
					if ([imageList count]) {
						NSString	*imageURL	= [[imageList objectAtIndex: 0] objectForKey: @"source"];
						
						[self setFBSampleImage: imageURL];
					}
				}
			}
			break;
			
		default:
			break;
	}
}

- (void)request:(FBRequest *)request didFailWithError:(NSError *)error
{
    NSLog(@"Error while requesting FB: %@", [error localizedDescription]);
}

@end
