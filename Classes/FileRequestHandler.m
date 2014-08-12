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
#import "HTTPErrorResponse.h"
#import "HTTPDynamicFileResponse.h"
#import "HTTPLogging.h"
#import "NSString+URLcodec.h"

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
	NSComparisonResult downloadFile = [path caseInsensitiveCompare:@"downloadfile"];
	NSComparisonResult newFolder = [path caseInsensitiveCompare:@"newfolder"];
	NSComparisonResult files = [path caseInsensitiveCompare:@"home"];
	return listFiles == NSOrderedSame || downloadFile == NSOrderedSame || files == NSOrderedSame || newFolder == NSOrderedSame;
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
	
	if ([self.request.method isEqualToString:@"GET"])
	{
        if (NSOrderedSame == [relativePath caseInsensitiveCompare:@"listfile"])
        {
			return [self handleListFile];
        }
		else if (NSOrderedSame == [relativePath caseInsensitiveCompare:@"home"])
        {
			return [self handleShowFile];
        }
        return nil;
	}
	else if (([method isEqualToString:@"POST"]))
	{
        if (NSOrderedSame == [relativePath caseInsensitiveCompare:@"deletefile"])
        {
			return [self handleDeleteFile];
        }
        else if (NSOrderedSame == [relativePath caseInsensitiveCompare:@"downloadfile"])
        {
            return [self handleDownloadFile];
        }
        else if (NSOrderedSame == [relativePath caseInsensitiveCompare:@"newfolder"])
        {
            return [self handleNewFolder];
        }
        return [self handleUploadFile];
	}
    return nil;
}

- (NSObject<HTTPResponse> *)handleListFile
{
    NSString *targetPath = self.request.url.path;
    NSRange removeRange = [targetPath rangeOfString:@"listfile" options:NSCaseInsensitiveSearch];
    if (removeRange.location != NSNotFound)
    {
        targetPath = [targetPath substringFromIndex:removeRange.location+removeRange.length];
    }
    
	NSMutableString *output = [[NSMutableString alloc] init];
	[output appendString:@"["];
    //Note: Files are sorted by creation date.
	for (Entity *entity in [[FileManager sharedInstance] getFileArrayFromPath:targetPath])
    {
		NSString* filename = entity.name;
		NSString* file = [filename stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"] ;
		[output appendFormat:@"{\"name\":\"%@\"},", file];
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
    NSRange removeRange = [targetPath rangeOfString:@"home" options:NSCaseInsensitiveSearch];
    if (removeRange.location != NSNotFound)
    {
        targetPath = [targetPath substringFromIndex:removeRange.location+removeRange.length];
    }
    Entity *targetEntity = [[FileManager sharedInstance] getEntityFromPath:targetPath];
    
    if (targetEntity && [targetEntity isKindOfClass:[Directory class]])
    {
        NSString *indexPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Web/index.html"];
        
        NSMutableDictionary *replacementDict = [NSMutableDictionary dictionaryWithCapacity:3];
        
        Entity *parentDir = targetEntity.parentDir;
        if (parentDir)
        {
            NSMutableString *navigation = [NSMutableString new];
            NSString *iconString = @"<img class='navigate-icon' src='/images/icon_navigate.png'>";
            NSMutableString *parentURL = [[NSMutableString alloc] initWithString:self.request.url.path];
            while (parentDir.parentDir) {
                [parentURL appendFormat:@"/.."];
                NSString *parentString = [NSString stringWithFormat:@"%@<a href='%@'>%@</a>", iconString, parentURL, parentDir.name];
                [navigation insertString:parentString atIndex:0];
                parentDir = parentDir.parentDir;
            }
            [navigation appendString:iconString];
            [navigation appendString:targetEntity.name];
            
            [replacementDict setObject:navigation forKey:@"NAVIGATION"];
        }
        else
        {
            //Note: For root directory, do not show the path.
            [replacementDict setObject:@"" forKey:@"NAVIGATION"];
        }
        
        [replacementDict setObject:[targetPath isEqualToString:@"/"]?@"":targetPath forKey:@"FILE_PATH"];
        
        HTTPLogVerbose(@"%@[%p]: replacementDict = \n%@", THIS_FILE, self, replacementDict);
        
        return [[HTTPDynamicFileResponse alloc] initWithFilePath:indexPath
                                                   forConnection:self.connection
                                                       separator:@"%%"
                                           replacementDictionary:replacementDict];
    }
    else if (targetEntity && [targetEntity isKindOfClass:[File class]])
    {
        return [[HTTPFileResponse alloc] initWithFilePath:targetEntity.url.path fileName:targetEntity.name forDownload:NO forConnection:self.connection];
    }
    return nil;
}

- (NSObject<HTTPResponse> *)handleUploadFile
{
    NSString *targetPath = self.request.url.path;
    NSRange removeRange = [targetPath rangeOfString:@"home" options:NSCaseInsensitiveSearch];
    if (removeRange.location != NSNotFound)
    {
        targetPath = [targetPath substringFromIndex:removeRange.location+removeRange.length];
    }
    
	NSString *filename = [self.parameters objectForKey:@"files[]"];
	NSString *tmpfile = [self.parameters objectForKey:@"tmpfilename"];
    [[FileManager sharedInstance] newFileWithName:filename path:targetPath tmpPath:tmpfile];
    return [[HTTPErrorResponse alloc] initWithErrorCode:200];
}

- (NSObject<HTTPResponse> *)handleDownloadFile
{
	NSString *path = [self.parameters objectForKey:@"path"];
	NSString *files = [self.parameters objectForKey:@"files"];
    NSString *downloadPath = [[FileManager sharedInstance] getDownloadFilePathForFiles:[files URLDecode] atPath:[path URLDecode]];
    if (downloadPath)
    {
        return [[HTTPFileResponse alloc] initWithFilePath:downloadPath fileName:[downloadPath lastPathComponent] forDownload:YES forConnection:self.connection];
    }
    return nil;
}

- (NSObject<HTTPResponse> *)handleDeleteFile
{
	NSString *path = [self.parameters objectForKey:@"path"];
	NSString *files = [self.parameters objectForKey:@"delete"];
    [[FileManager sharedInstance] deleteFilesWithName:files atPath:path];
    return [[HTTPErrorResponse alloc] initWithErrorCode:200];
}

- (NSObject<HTTPResponse> *)handleNewFolder
{
	NSString *path = [self.parameters objectForKey:@"path"];
	NSString *folderName = [self.parameters objectForKey:@"folder"];
    //Note: files should be @"file1,file2,file3,"
    if (folderName && folderName.length)
    {
        [[FileManager sharedInstance] newFolderWithName:folderName atPath:path];
    }
    return [[HTTPErrorResponse alloc] initWithErrorCode:200];
}

@end
