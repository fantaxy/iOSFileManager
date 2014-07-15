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

- (Entity *)getEntityFromPath:(NSString *)path
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
        Entity *entity = nil;
        Directory *dir = self.rootDir;
        for (int i = 0; i < array.count; i++)
        {
            entity = [dir getEntityFromPath:array[i]];
            if (i == array.count-1)
            {
                return entity;
            }
            else
            {
                if (entity && [entity isKindOfClass:[Directory class]])
                {
                    // Keep on diving.
                    dir = (Directory *)entity;
                }
                else
                {
                    NSLog(@"ERROR: The path %@ is illegal. %@ is a file, not a directory.", path, entity.name);
                    return nil;
                }
            }
        }
        return entity;
    }
}

- (Directory *)getDirectoryFromPath:(NSString *)path
{
    Entity *entity = [self getEntityFromPath:path];
    if (entity && [entity isKindOfClass:[Directory class]])
    {
        return (Directory *)entity;
    }
    NSLog(@"ERROR: The path %@ is not a directory.", path);
    return nil;
}

- (void)newFileWithName:(NSString *)fileName path:(NSString *)path tmpPath:(NSString *)tmpPath
{
    Directory *dir = [self getDirectoryFromPath:path];
    [dir addFileWithName:fileName inTempPath:tmpPath];
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
