//
//  FileManager.m
//  iPhoneHTTPServer
//
//  Created by yangx2 on 7/12/14.
//
//

#import "FileManager.h"
#import "File.h"
#import "Directory.h"

@interface FileManager ()

@property (nonatomic, strong) NSFileManager *fileManager;
@property (nonatomic, strong) Directory *rootDir;

@end

@implementation FileManager

static FileManager *sharedInstance;

+ (FileManager *)sharedInstance
{
    if (sharedInstance == nil)
    {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            sharedInstance = [[FileManager alloc] initialize];
        });
    }
    return sharedInstance;
}

- (instancetype)initialize
{
    if ([super init]) {
        _fileManager = [[NSFileManager alloc] init];
        NSURL *rootURL = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
        _rootDir = [[Directory alloc] initWithURL:rootURL name:@"root" creationDate:[NSDate date] type:@"root"];
        [_rootDir buildHierachy];
    }
    return self;
}

-(Directory *)getDirectoryFromPath:(NSString *)path
{
    if (!path)
    {
        return nil;
    }
    if ([path isEqualToString:@"/"] || [path isEqualToString:@""])
    {
        return self.rootDir;
    }
    else
    {
        if ([path hasPrefix:@"/"])
        {
            path = [path substringFromIndex:1];
        }
        if ([path hasSuffix:@"/"])
        {
            path = [path substringToIndex:path.length-1];
        }
        NSArray *array = [path componentsSeparatedByString:@"/"];
        if (!array.count)
        {
            return nil;
        }
        Directory *dir = self.rootDir;
        for (int i = 0; i < array.count; i++)
        {
            Entity *entity = [dir getEntityFromPath:array[i]];
            if (entity && [entity isKindOfClass:[Directory class]])
            {
                dir = (Directory *)entity;
            }
            else
            {
                return nil;
            }
        }
        return dir;
    }
}






//- (Directory *)getDirectoryFromURL:(NSURL *)dirUrl
//{
////    NSURL *docRoot = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
//    
//    
//    NSError *error = nil;
//    NSArray *properties = [NSArray arrayWithObjects:
//                           NSURLNameKey,
//                           NSURLCreationDateKey,
//                           NSURLIsDirectoryKey,
//                           NSURLLocalizedTypeDescriptionKey, nil];
//    
//    NSArray *array = [[NSFileManager defaultManager]
//                      contentsOfDirectoryAtURL:dirUrl
//                      includingPropertiesForKeys:properties
//                      options:(NSDirectoryEnumerationSkipsHiddenFiles)
//                      error:&error];
//    if (array == nil) {
//        return nil;
//    }
//    else
//    {
//        return [[Directory alloc] initWithURL:dirUrl fileArray:array];
//    }
//    
//}
//
//- (Directory *)getDirectoryFromPath:(NSString *)path
//{
//    return nil;
//}

@end
