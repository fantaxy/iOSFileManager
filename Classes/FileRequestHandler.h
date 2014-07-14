//
//  FileRequestHandler.h
//  iPhoneHTTPServer
//
//  Created by yangx2 on 7/13/14.
//
//

#import <Foundation/Foundation.h>
#import "HTTPConnection.h"

@interface FileRequestHandler : NSObject

+ (BOOL)canHandle:(HTTPMessage *)request;
- (id)initWithConnection:(HTTPConnection *)conn request:(HTTPMessage *)request;
- (NSObject<HTTPResponse> *)handleRequest;

@end
