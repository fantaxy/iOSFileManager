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
    _fileDict = [[NSMutableDictionary alloc] init];
}

- (void)buildHierachy
{
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
                [dir buildHierachy];
                [self.fileDict setObject:dir forKey:fileName];
            }
            else
            {
                File *file = [[File alloc] initWithURL:theURL name:fileName creationDate:creationDate type:typeDescription];
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

- (NSString *)fileNameAtIndex:(NSInteger)index
{
    Entity *entity = (Entity *)self.fileDict.allValues[index];
    return entity.name;
}

@end
