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
- (void)newFileWithName:(NSString *)fileName path:(NSString *)path tmpPath:(NSString *)tmpPath;

@end
