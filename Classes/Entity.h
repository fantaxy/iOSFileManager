//
//  Entity.h
//  iPhoneHTTPServer
//
//  Created by yangx2 on 7/13/14.
//
//

#import <Foundation/Foundation.h>
@class Directory;

@interface Entity : NSObject

@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSDate *creationDate;
@property (nonatomic, strong) NSString *type;
@property (nonatomic, weak) Directory *parentDir;

- (instancetype)initWithURL:(NSURL *)url name:(NSString *)name creationDate:(NSDate *)date type:(NSString *)type;
- (void)initialize;
- (BOOL)delete;

@end
