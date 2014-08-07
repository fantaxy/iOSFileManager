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

static const int httpLogLevel = HTTP_LOG_LEVEL_WARN; // | HTTP_LOG_FLAG_TRACE;
#define SEPARATOR @"+"

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
	NSComparisonResult files = [path caseInsensitiveCompare:@"home"];
	return listFiles == NSOrderedSame || downloadFile == NSOrderedSame || files == NSOrderedSame;
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
    //Note: Files are sorted by creation date.
	for (Entity *entity in [targetDir sortedFileArray])
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
    NSRange removeRange = [targetPath rangeOfString:@"home"];
    if (removeRange.location != NSNotFound)
    {
        targetPath = [targetPath substringFromIndex:removeRange.location+removeRange.length];
    }
    Entity *targetEntity = [[FileManager sharedInstance] getEntityFromPath:targetPath];
    
    if (targetEntity && [targetEntity isKindOfClass:[Directory class]])
    {
        NSString *indexPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Web/index.html"];
        
        NSMutableDictionary *replacementDict = [NSMutableDictionary dictionaryWithCapacity:3];
        
        NSMutableString *navigation = [NSMutableString new];
        NSString *iconString = @"<img class='navigate-icon' src='/images/icon_navigate.png'>";
        Entity *parentDir = targetEntity.parentDir;
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
    NSRange removeRange = [targetPath rangeOfString:@"home"];
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
    Directory *parentDir = [[FileManager sharedInstance] getDirectoryFromPath:path];
    //Note: files should be @"file1,file2,file3,"
    if (files && files.length)
    {
        if ([files hasSuffix:SEPARATOR])
        {
            files = [files substringToIndex:files.length-1];
        }
        NSArray *fileNameArray = [files componentsSeparatedByString:SEPARATOR];
        if (fileNameArray.count == 1)
        {
            Entity *entity = [parentDir getEntityFromPath:[fileNameArray firstObject]];
            if ([entity isKindOfClass:[Directory class]])
            {
                //Zip the dir to entityName.zip
            }
            else
            {
                return [[HTTPFileResponse alloc] initWithFilePath:entity.url.path fileName:entity.name forDownload:YES forConnection:self.connection];
            }
        }
        else if (fileNameArray.count > 1)
        {
            NSMutableArray *fileArray = [NSMutableArray new];
            for (NSString *fileName in fileNameArray)
            {
                Entity *entity = [parentDir getEntityFromPath:fileName];
                if (entity)
                {
                    [fileArray addObject:entity];
                }
            }
            //Zip all files to parentDirName.zip
        }
    }
    return nil;
}

- (NSObject<HTTPResponse> *)handleDeleteFile
{
	NSString *path = [self.parameters objectForKey:@"path"];
	NSString *files = [self.parameters objectForKey:@"delete"];
    //Note: files should be @"file1,file2,file3,"
    if (files && files.length)
    {
        if ([files hasSuffix:SEPARATOR])
        {
            files = [files substringToIndex:files.length-1];
        }
        NSArray *fileArray = [files componentsSeparatedByString:SEPARATOR];
        Directory *dir = [[FileManager sharedInstance] getDirectoryFromPath:path];
        NSParameterAssert(dir);
        [dir deleteFilesWithArray:fileArray];
    }
    return [[HTTPErrorResponse alloc] initWithErrorCode:200];
}

@end
