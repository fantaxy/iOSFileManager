//
//  MYHttpConnection.m
//  iPhoneHTTPServer
//
//  Created by yangx2 on 7/6/14.
//
//

#import "MYHttpConnection.h"
#import "HTTPDynamicFileResponse.h"
#import "HTTPLogging.h"
#import "HTTPMessage.h"
#import "FileRequestHandler.h"
#import "HTTPServer.h"

// Log levels: off, error, warn, info, verbose
// Other flags: trace
static const int httpLogLevel = HTTP_LOG_LEVEL_WARN; // | HTTP_LOG_FLAG_TRACE;

@implementation MYHttpConnection

#pragma mark - Override method

- (BOOL)supportsMethod:(NSString *)method atPath:(NSString *)path
{
	HTTPLogTrace();
	
	// Add support for POST
	
	if ([method isEqualToString:@"POST"])
	{
		return YES;
	}
	
	return [super supportsMethod:method atPath:path];
}

- (BOOL)expectsRequestBodyFromMethod:(NSString *)method atPath:(NSString *)path
{
	HTTPLogTrace();
	
	// Inform HTTP server that we expect a body to accompany a POST request
	
	if([method isEqualToString:@"POST"])
		return YES;
	
	return [super expectsRequestBodyFromMethod:method atPath:path];
}

- (BOOL)hasCustomRequest
{
    if ([FileRequestHandler canHandle:request])
    {
        return YES;
    }
    else
    {
        return [super hasCustomRequest];
    }
}

- (NSObject<HTTPResponse> *)customResponseForMethod:(NSString *)method URI:(NSString *)path
{
    return [[[FileRequestHandler alloc] initWithConnection:self request:request] handleRequest];
}

-(NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path
{
    NSString *postStr = nil;
    
    NSData *postData = [request body];
    if (postData)
    {
        postStr = [[NSString alloc] initWithData:postData encoding:NSUTF8StringEncoding];
    }
    
    HTTPLogVerbose(@"%@[%p]: postStr: %@", THIS_FILE, self, postStr);
    
    
	NSString *filePath = [self filePathForURI:path allowDirectory:NO];
	
	BOOL isDir = NO;
	
	if (filePath && [[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:&isDir] && !isDir)
	{        
        NSMutableDictionary *replacementDict = [NSMutableDictionary dictionaryWithCapacity:3];
        
        [replacementDict setObject:@"" forKey:@"FILE_PATH"];
        
        HTTPLogVerbose(@"%@[%p]: replacementDict = \n%@", THIS_FILE, self, replacementDict);
        
        return [[HTTPDynamicFileResponse alloc] initWithFilePath:filePath
                                                   forConnection:self
                                                       separator:@"%%"
                                           replacementDictionary:replacementDict];
	}
    return nil;
}

- (void)prepareForBodyWithSize:(UInt64)contentLength
{
	HTTPLogTrace();
	
	// If we supported large uploads,
	// we might use this method to create/open files, allocate memory, etc.
}

- (void)processBodyData:(NSData *)postDataChunk
{
	HTTPLogTrace();
	
	// Remember: In order to support LARGE POST uploads, the data is read in chunks.
	// This prevents a 50 MB upload from being stored in RAM.
	// The size of the chunks are limited by the POST_CHUNKSIZE definition.
	// Therefore, this method may be called multiple times for the same POST request.
	
	NSString *body = [[NSString alloc] initWithBytes:[postDataChunk bytes] length:[postDataChunk length] encoding:NSUTF8StringEncoding];
	NSArray* paramstr = [body componentsSeparatedByString:@"&"];
	
	for (NSString* pair in paramstr)
	{
		NSArray* keyvalue = [pair componentsSeparatedByString:@"="];
		if ([keyvalue count] == 2)
			[request.params setObject:[keyvalue objectAtIndex:1] forKey:[[keyvalue objectAtIndex:0] lowercaseString]];
		else
			HTTPLogError(@"%@[%p]: %@ - misformat parameters in POST:%@", THIS_FILE, self, THIS_METHOD, pair);
	}
}

@end
