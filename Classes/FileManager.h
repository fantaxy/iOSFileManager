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

- (Directory *)getDirectoryFromPath:(NSString *)path;

@end
