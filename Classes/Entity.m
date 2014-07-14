//
//  Entity.m
//  iPhoneHTTPServer
//
//  Created by yangx2 on 7/13/14.
//
//

#import "Entity.h"

@interface Entity ()

@end

@implementation Entity

- (instancetype)initWithURL:(NSURL *)url name:(NSString *)name creationDate:(NSDate *)date type:(NSString *)type
{
    self = [super init];
    if (self)
    {
        self.url = url;
        self.name = name;
        self.creationDate = date;
        self.type = type;
        [self initialize];
    }
    return self;
}

- (void)initialize
{
    // Override to perform extra initialization.
}


- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ File name: %@ URL: %@ Create at: %@ Type: %@", self.class, self.name, self.url, self.creationDate, self.type];
}

@end
