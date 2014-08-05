#import <Foundation/Foundation.h>
#import "HTTPResponse.h"

@class HTTPConnection;


@interface HTTPFileResponse : NSObject <HTTPResponse>
{
	HTTPConnection *connection;
	
	NSString *filePath;
	UInt64 fileLength;
	UInt64 fileOffset;
	
	BOOL aborted;
    BOOL forDownload;
	
	int fileFD;
	void *buffer;
	NSUInteger bufferSize;
}

- (id)initWithFilePath:(NSString *)fpath forDownload:(BOOL)download forConnection:(HTTPConnection *)parent;
- (NSString *)filePath;

@end
