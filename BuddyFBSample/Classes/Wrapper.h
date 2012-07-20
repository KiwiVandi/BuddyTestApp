
// Sample Code ©  Buddy Platform, Inc. – 2011. 
// Code may be freely referenced and redistributed.

#import <Foundation/Foundation.h> 
#import "WrapperDelegate.h"

@class Wrapper;

typedef void (^WrapperResultBlock)(Wrapper *wrapper, NSError *error);

@interface Wrapper : NSObject 
{
@private
    NSMutableData		*receivedData;
    NSURLConnection		*conn;
}

@property (nonatomic, readonly) NSData							*receivedData;
@property (nonatomic, readonly) NSString						*apiName;
@property (nonatomic, assign) BOOL								asynchronous;
@property (nonatomic, copy) NSString							*mimeType;
@property (nonatomic, unsafe_unretained) id<WrapperDelegate>	delegate; // Do not retain delegates!

- (id)initWithBlock: (WrapperResultBlock)aBlock;

//makes the request to the server
- (void)sendRequestTo: (NSString *)urlString
			usingVerb: (NSString *)verb
	   withParameters: (NSDictionary *)parameters
		  withAPIName: (NSString*)apiName;

//cancels the connection
- (void)cancelConnection;

//returns the string form of NSData, encoded in UTF8
- (NSString *)responseAsText;

//returns the object obtained by parsing as JSON
- (id)responseAsObject;

@end
