
// Sample Code ©  Buddy Platform, Inc. – 2011. 
// Code may be freely referenced and redistributed.

#import <Foundation/Foundation.h> 

@class Wrapper;

@protocol WrapperDelegate <NSObject>

@required
- (void)wrapper:(Wrapper *)wrapper didRetrieveData:(NSData *)data;

@optional
- (void)wrapper:(Wrapper *)wrapper didFailWithError:(NSError *)error;
- (void)wrapper:(Wrapper *)wrapper didReceiveStatusCode:(int)statusCode;

@end