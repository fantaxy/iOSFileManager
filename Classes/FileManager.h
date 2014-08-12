//
//  FileManager.h
//  iPhoneHTTPServer
//
//  Created by yangx2 on 7/12/14.
//
//

#import <Foundation/Foundation.h>
#import "Directory.h"

@interface FileManager : NSObject

+ (FileManager *)sharedInstance;

- (Entity *)getEntityFromPath:(NSString *)path;
- (Directory *)getDirectoryFromPath:(NSString *)path;
- (NSArray *)getFileArrayFromPath:(NSString *)path;
- (NSString *)getDownloadFilePathForFiles:(NSString *)fileNames atPath:(NSString *)path;
- (void)newFileWithName:(NSString *)fileName path:(NSString *)path tmpPath:(NSString *)tmpPath;
- (void)newFolderWithName:(NSString *)folderName atPath:(NSString *)path;
- (void)deleteFilesWithName:(NSString *)fileNames atPath:(NSString *)path;

@end
