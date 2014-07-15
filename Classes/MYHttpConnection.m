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

@interface MYHttpConnection ()
{
    BOOL isMultipartEncoding;
    BOOL hasParsedMultipartHead;
    NSString *boundaryString;
    NSFileHandle *tmpUploadFileHandle;
	NSData *remainBody;
}

@end

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
    
    // init body info
    NSString* contentType = [request headerField:@"Content-Type"];
    if (nil != contentType)
    {
        // checkout boundary
        NSError *error;
        NSRange searchRange = NSMakeRange(0, [contentType length]);
        NSRange matchedRange = NSMakeRange(NSNotFound, 0);
        NSRegularExpression *regex = [[NSRegularExpression alloc] initWithPattern:@"\\Amultipart/form-data.*boundary=\"?([^\";,]+)\"?" options:NSRegularExpressionCaseInsensitive error:&error];
        NSTextCheckingResult *match = [regex firstMatchInString:contentType options:0 range:searchRange];
        if ([match numberOfRanges] >= 1) {
            matchedRange = [match rangeAtIndex:1];
        }
        if (matchedRange.location != NSNotFound)
        {
            boundaryString = [NSString stringWithFormat:@"%@%@", @"--", [contentType substringWithRange:matchedRange]];
            // Begin to parse the multipart header, do some initialization.
            isMultipartEncoding = YES;
            hasParsedMultipartHead = NO;
            remainBody = nil;
        }
        else
        {
            boundaryString = nil;
            isMultipartEncoding = NO;
            hasParsedMultipartHead = NO;
        }
    }
}

- (void)parsePostData:(NSString *)body
{
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

- (void)processBodyData:(NSData *)postDataChunk
{
	HTTPLogTrace();
	
	// Remember: In order to support LARGE POST uploads, the data is read in chunks.
	// This prevents a 50 MB upload from being stored in RAM.
	// The size of the chunks are limited by the POST_CHUNKSIZE definition.
	// Therefore, this method may be called multiple times for the same POST request.
	
    NSString *body = [[NSString alloc] initWithBytes:[postDataChunk bytes] length:[postDataChunk length] encoding:NSUTF8StringEncoding];
    
    if (isMultipartEncoding)
    {
        if (!hasParsedMultipartHead)
        {
            [self parseMultipartHeader:postDataChunk];
            hasParsedMultipartHead = YES;
        }
        else
        {
            [self parseMultipartBody:postDataChunk];
        }
    }
    else
    {
        [self parsePostData:body];
    }
}

/* parsing head info for multipart body */
- (void)parseMultipartHeader:(NSData*)body
{
    HTTPLogVerbose(@"Parsing multipart header...");
	NSString * EOL = @"\015\012";
	// check boundary
	NSRange boundaryRange = NSMakeRange(0, [boundaryString length] + [EOL length]);
	NSString *boundary = [NSString stringWithUTF8String:(const char *)[[body subdataWithRange:boundaryRange] bytes]];
	if (![boundary isEqualToString:[NSString stringWithFormat:@"%@%@", boundaryString, EOL]])
	{
		HTTPLogVerbose(@"bad content body");
		return;
	}
	
	// read head to get file name
	NSRange contentRange = NSMakeRange([boundaryString length] + [EOL length], [body length]- [boundaryString length] - [EOL length]);
	const char* contentBytes = [[body subdataWithRange:contentRange] bytes];
	int contentLength = contentRange.length;
	const char* dEOL = "\015\012\015\012";
	const char *headEnd = strstr(contentBytes, dEOL);
	NSString *bodyHeader = [[NSString alloc] initWithBytes:contentBytes length:(headEnd - contentBytes) encoding:NSUTF8StringEncoding];
    int headLength = bodyHeader.length;
    
    NSError *error;
    NSRange searchRange = NSMakeRange(0, [bodyHeader length]);
    NSRange matchedRange = NSMakeRange(NSNotFound, 0);
    NSRegularExpression *regex = [[NSRegularExpression alloc]
                                  initWithPattern:@"Content-Disposition:.* filename=(?:\"((?:\\\\.|[^\\\"])*)\"|([^;]*))"
                                  options:NSRegularExpressionCaseInsensitive
                                  error:&error];
    NSTextCheckingResult *match = [regex firstMatchInString:bodyHeader options:0 range:searchRange];
    if ([match numberOfRanges] >= 1) {
        matchedRange = [match rangeAtIndex:1];
    }
		
	NSString *filename = [bodyHeader substringWithRange:matchedRange];
    
//	if ([userAgent isMatchedByRegex:@"MSIE .* Windows "]
//		&& [filename isMatchedByRegex:@"\\A([a-zA-Z]:\\\\|\\\\\\\\)"])
//	{
//		NSArray *pathSegs = [filename componentsSeparatedByString:@"\\"];
//		filename = [pathSegs lastObject];
//	}
	
    regex = [[NSRegularExpression alloc]
             initWithPattern:@"Content-Disposition:.* name=\"?([^\\\";]*)\"?"
             options:NSRegularExpressionCaseInsensitive
             error:&error];
    match = [regex firstMatchInString:bodyHeader options:0 range:searchRange];
    if ([match numberOfRanges] >= 1) {
        matchedRange = [match rangeAtIndex:1];
    }
	NSString *key = [bodyHeader substringWithRange:matchedRange];
	[request.params setObject:filename forKey:key];
	
    NSUUID *theUUID = [NSUUID UUID];
	NSString *tmpName = [NSString stringWithFormat:@"%@/%@", NSTemporaryDirectory(), [theUUID UUIDString]];
	NSFileManager *fm = [NSFileManager defaultManager];
	[fm createFileAtPath:tmpName contents:[NSData data] attributes:nil];
	tmpUploadFileHandle = [NSFileHandle fileHandleForWritingAtPath:tmpName];
	[request.params setObject:tmpName forKey:@"tmpfilename"];
	
	int fileLength = contentLength - (headLength + strlen(dEOL));
	const char *filePointer = headEnd + strlen(dEOL);
	NSData *fileContent = [NSData dataWithBytesNoCopy:(void *)filePointer length:fileLength freeWhenDone:NO];
    
	[self parseMultipartBody:fileContent];
}

- (void)parseMultipartBody:(NSData*)body
{
	if (nil == tmpUploadFileHandle)
		return;
	
	static NSString* dEOL = @"\015\012";
	NSString *terminator = [NSString stringWithFormat:@"%@%@", dEOL, boundaryString];
	NSMutableData *data = [[NSMutableData alloc] init];
	if (remainBody)
		[data appendData:remainBody];
	[data appendData:body];
	
    //Note: Start looking for terminator from the first \015 down to the end,
    //      if the first \015 is not part of terminator, check next \015.
	const char* beginning = [data bytes];
	const char* cterminator = [terminator UTF8String];
	const char* candidate = memchr(beginning, '\015', [data length]);
	const char* contentEnd = NULL;
	int taillen = beginning + [data length] - candidate;
	while (candidate && taillen >= [terminator length]) {
		contentEnd = strnstr(candidate, cterminator, [terminator length]);
		if (contentEnd)
			break;
		candidate = memchr(candidate+1, '\015', taillen - 1);
		taillen = beginning + [data length] - candidate;
	}
	if (NULL != contentEnd)
	{
        // Reach the EOL.
		NSRange range = NSMakeRange(0, contentEnd - beginning);
		NSData* content = [data subdataWithRange:range];
		[tmpUploadFileHandle writeData:content];
        [tmpUploadFileHandle closeFile];
        tmpUploadFileHandle = nil;
	}
	else
	{
        // Put last chars size of terminator into next read
		NSRange range = NSMakeRange(0, [data length] - [terminator length]);
		NSData* content = [data subdataWithRange:range];
		range = NSMakeRange([data length] - [terminator length], [terminator length]);
		remainBody = [data subdataWithRange:range];
		
		[tmpUploadFileHandle writeData:content];
	}
}

@end
