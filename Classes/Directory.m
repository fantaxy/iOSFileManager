//
//  Directory.m
//  iPhoneHTTPServer
//
//  Created by yangx2 on 7/12/14.
//
//

#import "Directory.h"
#import "File.h"
#import "Entity.h"

@interface Directory ()

@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) NSMutableDictionary *fileDict;

@end

@implementation Directory

- (void)initialize
{
}

- (void)buildHierachy
{
    _fileDict = [[NSMutableDictionary alloc] init];
    
    NSError *error = nil;
    NSArray *properties = [NSArray arrayWithObjects:
                           NSURLNameKey,
                           NSURLCreationDateKey,
                           NSURLIsDirectoryKey,
                           NSURLLocalizedTypeDescriptionKey, nil];
    
    NSArray *array = [[NSFileManager defaultManager]
                      contentsOfDirectoryAtURL:self.url
                      includingPropertiesForKeys:properties
                      options:(NSDirectoryEnumerationSkipsHiddenFiles)
                      error:&error];
    if (array == nil && !error)
    {
        NSLog(@"%@", error);
    }
    else
    {
        NSString *fileName;
        NSDate *creationDate;
        NSString *typeDescription;
        NSNumber *isDirectory;
        for (NSURL *theURL in array)
        {
            [theURL getResourceValue:&fileName forKey:NSURLNameKey error:NULL];
            [theURL getResourceValue:&creationDate forKey:NSURLCreationDateKey error:NULL];
            [theURL getResourceValue:&typeDescription forKey:NSURLLocalizedTypeDescriptionKey error:NULL];
            [theURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:NULL];
            
            if ([isDirectory boolValue])
            {
                Directory *dir = [[Directory alloc] initWithURL:theURL name:fileName creationDate:creationDate type:typeDescription];
                dir.parentDir = self;
                [dir buildHierachy];
                [self.fileDict setObject:dir forKey:fileName];
            }
            else
            {
                File *file = [[File alloc] initWithURL:theURL name:fileName creationDate:creationDate type:typeDescription];
                file.parentDir = self;
                [self.fileDict setObject:file forKey:fileName];
            }
        }
        
    }
}

- (Entity *)getEntityFromPath:(NSString *)path
{
    return self.fileDict[path];
}

- (NSInteger)numberOfFiles
{
    return self.fileDict.count;
}

- (NSArray *)sortedFileArray
{
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"creationDate" ascending:YES];
    return [self.fileDict.allValues sortedArrayUsingDescriptors:[NSArray arrayWithObject:sortDescriptor]];
}

- (void)addFileWithName:(NSString *)name inTempPath:(NSString *)tmpPath
{
    if (name == nil || tmpPath == nil)
		return;
	NSString *path = [NSString stringWithFormat:@"%@/%@", self.url.path, name];
	NSFileManager *fm = [NSFileManager defaultManager];
	NSError *error;
	if (![fm moveItemAtPath:tmpPath toPath:path error:&error])
	{
		NSLog(@"Can not move %@ to %@ because: %@", tmpPath, path, error );
        return;
	}
    [self buildHierachy];
}

- (void)deleteFilesWithArray:(NSArray *)files
{
    for (NSString *path in files)
    {
        Entity *entity = [self getEntityFromPath:path];
        [entity delete];
    }
    [self buildHierachy];
}

@end
