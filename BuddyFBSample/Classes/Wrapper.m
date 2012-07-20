
// Sample Code ©  Buddy Platform, Inc. – 2011. 
// Code may be freely referenced and redistributed.

#import "Wrapper.h"
#import "NSData+Base64.h"

static	NSInteger	openConnections	= 0;

@interface Wrapper ()
@property (strong, nonatomic) WrapperResultBlock	callbackBlock;

- (void)startConnection:(NSURLRequest *)request;
@end

@implementation Wrapper

@synthesize receivedData;
@synthesize apiName			= _apiName;
@synthesize asynchronous	= _asynchronous;
@synthesize mimeType		= _mimeType;
@synthesize delegate		= _delegate;

@synthesize callbackBlock	= _callbackBlock;

#pragma mark - Constructor and destructor

- (id)init
{
    if (self = [super init])
    {
        receivedData		= [[NSMutableData alloc] initWithCapacity: 256];
        conn				= nil;
        
		_apiName			= nil;
        self.asynchronous	= YES;
        self.mimeType		= @"text/html";
        self.delegate		= nil;
    }
    
    return self;
}

- (id)initWithBlock: (WrapperResultBlock)aBlock
{
	if (self = [self init]) {
		self.callbackBlock	= aBlock;
	}
	
	return self;
}

- (void)dealloc
{
	_apiName		= nil;
    self.mimeType	= nil;
}

#pragma mark - Public methods

- (void)sendRequestTo: (NSString *)urlString
			usingVerb: (NSString *)verb
	   withParameters: (NSDictionary *)parameters
		  withAPIName: (NSString*)apiName
{
    NSData			*body			= nil;
    NSMutableString	*paramStr		= nil;
    NSString		*contentType	= @"text/html; charset=utf-8";
    NSURL			*finalURL;
	
	if(apiName != nil) {
		_apiName	= apiName;
		finalURL	= [NSURL URLWithString: [urlString stringByAppendingFormat: @"?%@", _apiName]];
	} else {
		finalURL	= [NSURL URLWithString: urlString];
	}
	
	
    if (parameters != nil)
    {
        paramStr = [NSMutableString stringWithCapacity: 256];
		
        for (id key in parameters)
        {
            NSString	*encodedKey	= [key stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
			id			origParam	= [parameters objectForKey:key];
            CFStringRef value;
			
			if ([origParam isKindOfClass: [NSData class]])
            {
				value	= (__bridge CFStringRef)[(NSData *)origParam base64EncodedString];
			} 
            else 
            {
				value	= (__bridge CFStringRef)[origParam description];
			}
			
            // Escape even the "reserved" characters for URLs 
            // as defined in http://www.ietf.org/rfc/rfc2396.txt
            CFStringRef encodedValue = CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, 
                                                                               value,
                                                                               NULL, 
                                                                               (CFStringRef)@"<>();/!?:@&=+$,", 
                                                                               kCFStringEncodingUTF8);
            [paramStr appendFormat:@"&%@=%@", encodedKey, encodedValue];
            CFRelease(encodedValue);
        }
    }
    
    if ([verb isEqualToString:@"POST"] || [verb isEqualToString:@"PUT"])
    {
        contentType = @"application/x-www-form-urlencoded; charset=utf-8";
        body = [[paramStr substringFromIndex: 1] dataUsingEncoding: NSUTF8StringEncoding];
    }
    else
    {
        if (parameters != nil)
        {
            NSString *urlWithParams	= [[finalURL absoluteString] stringByAppendingFormat:@"%@", paramStr];

            finalURL = [NSURL URLWithString:urlWithParams];
        }
    }
    
    NSMutableDictionary* headers = [[NSMutableDictionary alloc] init];
	
    [headers setValue:contentType forKey:@"Content-Type"];
    [headers setValue:self.mimeType forKey:@"Accept"];
    [headers setValue:@"no-cache" forKey:@"Cache-Control"];
    [headers setValue:@"no-cache" forKey:@"Pragma"];
    [headers setValue:@"close" forKey:@"Connection"]; // Avoid HTTP 1.1 "keep alive" for the connection
       
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL: finalURL
                                                           cachePolicy: NSURLRequestUseProtocolCachePolicy
                                                       timeoutInterval: 60.0];
    [request setHTTPMethod:verb];
    [request setAllHTTPHeaderFields:headers];
    if (parameters != nil)
    {
        [request setHTTPBody:body];
    }
    
    [self startConnection:request];
}

- (void)cancelConnection
{
	if (conn) {
		if (!(--openConnections))
			[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible: NO];
		[conn cancel];
		conn		= nil;
	}
}

- (NSString *)responseAsText
{
    return [[NSString alloc] initWithData: receivedData
								 encoding: NSUTF8StringEncoding];
}

- (id)responseAsObject
{
	NSError	*error	= nil;
	id		result	= [NSJSONSerialization JSONObjectWithData: receivedData
													  options: NSJSONReadingMutableContainers | NSJSONReadingAllowFragments
													    error: &error];
	
	if (!error && result) {
		return result;
	} else {
		NSLog(@"Error parsing JSON response: %@", [error localizedDescription]);		
	}
	
	return nil;
}

#pragma mark - Private methods

- (void)startConnection:(NSURLRequest *)request
{
    if (self.asynchronous)
    {
        [self cancelConnection];
        conn = [[NSURLConnection alloc] initWithRequest:request
                                               delegate:self
                                       startImmediately:YES];
        
        if (!conn)
        {
            if ([self.delegate respondsToSelector:@selector(wrapper:didFailWithError:)])
            {
                NSMutableDictionary* info = [NSMutableDictionary dictionaryWithObject: [request URL]
																			   forKey: NSURLErrorFailingURLStringErrorKey];
                [info setObject: @"Could not open connection"
						 forKey: NSLocalizedDescriptionKey];
                NSError* error = [NSError errorWithDomain: NSStringFromClass([self class]) code:1 userInfo:info];
				
                [self.delegate wrapper:self didFailWithError:error];
            }
        }
		
		if (!openConnections++)
			[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible: YES];
    }
    else
    {
        NSHTTPURLResponse	*response	= nil;
        NSError				*error		= nil;
        NSData				*data		= [NSURLConnection sendSynchronousRequest: request
																returningResponse: &response
																			error: &error];
		
		if ([response statusCode] != 200) {
			NSLog(@"Remote error sending request %@, code %d", [request URL], [response statusCode]);
		} else if (error) {
			NSLog(@"Local error sending request %@\n%@", [request URL], [error localizedDescription]);
		}
        [receivedData setData:data];
		
		_apiName	= nil;
   }
}

#pragma mark - NSURLConnection delegate methods

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
    int statusCode = [httpResponse statusCode];
    switch (statusCode)
    {
        case 200:
            break;        
        default:
        {
            if ([self.delegate respondsToSelector:@selector(wrapper:didReceiveStatusCode:)])
            {
                [self.delegate wrapper:self didReceiveStatusCode:statusCode];
            }
            break;
        }
    }
    [receivedData setLength:0];
    
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [receivedData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [self cancelConnection];
	
	if (self.callbackBlock)
		self.callbackBlock(self, error);
	
    if ([self.delegate respondsToSelector:@selector(wrapper:didFailWithError:)])
    {
        [self.delegate wrapper:self didFailWithError:error];
    }
	_apiName	= nil;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [self cancelConnection];
	
	if (self.callbackBlock)
		self.callbackBlock(self, nil);
    
    if ([self.delegate respondsToSelector:@selector(wrapper:didRetrieveData:)])
    {
        
        [self.delegate wrapper:self didRetrieveData:receivedData];
    }
	_apiName	= nil;
}

@end