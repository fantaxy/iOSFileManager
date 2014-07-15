//
//  FileRequestHandler.m
//  iPhoneHTTPServer
//
//  Created by yangx2 on 7/13/14.
//
//

#import "FileRequestHandler.h"
#import "HTTPServer.h"
#import "HTTPMessage.h"
#import "File.h"
#import "FileManager.h"
#import "HTTPDataResponse.h"
#import "HTTPFileResponse.h"
#import "HTTPDynamicFileResponse.h"
#import "HTTPLogging.h"

static const int httpLogLevel = HTTP_LOG_LEVEL_WARN; // | HTTP_LOG_FLAG_TRACE;

@interface FileRequestHandler ()

@property (nonatomic, strong) HTTPConnection *connection;
@property (nonatomic, strong) HTTPMessage *request;
@property (nonatomic, strong) NSDictionary *parameters;

@end

@implementation FileRequestHandler

+ (BOOL)canHandle:(HTTPMessage *)request
{
    if ([request.method isEqualToString:@"POST"])
    {
        return YES;
    }
	NSURL *url = request.url;
	NSString* fullpath = [url path];
    if (!fullpath || fullpath.length == 0)
    {
        return NO;
    }
	NSString* path = [[fullpath componentsSeparatedByString:@"/"] objectAtIndex:1];
	NSComparisonResult listFiles = [path caseInsensitiveCompare:@"listfile"];
	NSComparisonResult files = [path caseInsensitiveCompare:@"files"];
	return listFiles == NSOrderedSame || files == NSOrderedSame;
}

- (id)initWithConnection:(HTTPConnection*)conn request:(HTTPMessage *)request
{
	if (self = [super init])
	{
        _connection = conn;
        _request = request;
        _parameters = request.params;
	}
	return self;
}

- (NSObject<HTTPResponse> *)handleRequest
{
	NSString* path = self.request.url.path;
	NSString* relativePath = [[path componentsSeparatedByString:@"/"] objectAtIndex:1];
    
    NSString *method = self.request.method;
	NSString *_method = [self.parameters objectForKey:@"_method"];
	
	if ([self.request.method isEqualToString:@"GET"])
	{
        if (NSOrderedSame == [relativePath caseInsensitiveCompare:@"listfile"])
        {
			return [self handleListFile];
        }
		else if (NSOrderedSame == [relativePath caseInsensitiveCompare:@"files"])
        {
			return [self handleShowFile];
        }
        return nil;
	}
//	else if (([method isEqualToString:@"POST"]) && _method && [[_method lowercaseString] isEqualToString:@"delete"])
//	{
//		NSArray *segs = [path componentsSeparatedByString:@"/"];
//		if ([segs count] >= 2)
//		{
//			NSString* fileName = [segs objectAtIndex:2];
//			[self actionDelete:fileName];
//		}
//	}
	else if (([method isEqualToString:@"POST"]))
	{
		return [self handleUploadFile];
	}
    return nil;
}

- (NSObject<HTTPResponse> *)handleListFile
{
    NSString *targetPath = self.request.url.path;
    NSRange removeRange = [targetPath rangeOfString:@"listfile"];
    if (removeRange.location != NSNotFound)
    {
        targetPath = [targetPath substringFromIndex:removeRange.location+removeRange.length];
    }
    Directory *targetDir = [[FileManager sharedInstance] getDirectoryFromPath:targetPath];
    
	NSMutableString *output = [[NSMutableString alloc] init];
	[output appendString:@"["];
	for(int i = 0; i<[targetDir numberOfFiles]; ++i)
	{
		NSString* filename = [targetDir fileNameAtIndex:i];
		NSString* file = [filename stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"] ;
		[output appendFormat:@"{'name':'%@', 'id':%d},", file, i];
	}
	if ([output length] > 1)
	{
		NSRange range = NSMakeRange([output length] - 1, 1);
		[output replaceCharactersInRange:range withString:@"]"];
	}
	else
	{
		[output appendString:@"]"];
	}
	
    return [[HTTPDataResponse alloc] initWithData:[output dataUsingEncoding:NSUTF8StringEncoding]];
}

- (NSObject<HTTPResponse> *)handleShowFile
{
    NSString *targetPath = self.request.url.path;
    NSRange removeRange = [targetPath rangeOfString:@"files"];
    if (removeRange.location != NSNotFound)
    {
        targetPath = [targetPath substringFromIndex:removeRange.location+removeRange.length];
    }
    Entity *targetEntity = [[FileManager sharedInstance] getEntityFromPath:targetPath];
    
    if (targetEntity && [targetEntity isKindOfClass:[Directory class]])
    {
        NSString *indexPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Web/index.html"];
        
        NSMutableDictionary *replacementDict = [NSMutableDictionary dictionaryWithCapacity:3];
        
        [replacementDict setObject:[targetPath isEqualToString:@"/"]?@"":targetPath forKey:@"FILE_PATH"];
        
        HTTPLogVerbose(@"%@[%p]: replacementDict = \n%@", THIS_FILE, self, replacementDict);
        
        return [[HTTPDynamicFileResponse alloc] initWithFilePath:indexPath
                                                   forConnection:self.connection
                                                       separator:@"%%"
                                           replacementDictionary:replacementDict];
    }
    else if (targetEntity && [targetEntity isKindOfClass:[File class]])
    {
        return [[HTTPFileResponse alloc] initWithFilePath:targetEntity.url.path forConnection:self.connection];
    }
    return nil;
}


- (NSObject<HTTPResponse> *)handleUploadFile
{
    NSString *targetPath = self.request.url.path;
    NSRange removeRange = [targetPath rangeOfString:@"files"];
    if (removeRange.location != NSNotFound)
    {
        targetPath = [targetPath substringFromIndex:removeRange.location+removeRange.length];
    }
    
	NSString *filename = [self.parameters objectForKey:@"fileInput"];
	NSString *tmpfile = [self.parameters objectForKey:@"tmpfilename"];
    [[FileManager sharedInstance] newFileWithName:filename path:targetPath tmpPath:tmpfile];
    return [self handleShowFile];
}

@end
