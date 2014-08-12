//
//  Directory.h
//  iPhoneHTTPServer
//
//  Created by yangx2 on 7/12/14.
//
//

#import <Foundation/Foundation.h>
#import "Entity.h"

@interface Directory : Entity

- (void)buildHierachy;
- (Entity *)getEntityFromPath:(NSString *)path;

// number of the files
- (NSInteger)numberOfFiles;

// the sorted array of all files in this directory
- (NSArray *)sortedFileArray;

// handle newly uploaded file. After uploading, the file is stored in
// the temparory directory
- (void)addFileWithName:(NSString*)name inTempPath:(NSString*)tmpPath;

// handle newly added folder.
- (void)addFolderWithName:(NSString*)name;

// implement this method to delete requested file
- (void)deleteFilesWithArray:(NSArray *)files;

@end
