//
//  S3Connection.m
//
//  Copyright 2013 Symbiotic Software LLC. All rights reserved.
//
//  http://docs.aws.amazon.com/AmazonS3/latest/API/RESTObjectPUT.html
//

#import "S3Connection.h"
#import "NSDataAddition.h"
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonHMAC.h>
#import <MobileCoreServices/MobileCoreServices.h>

#define S3_URL						@"http://%@.s3.amazonaws.com/%@"
#define S3_SECURE_URL				@"https://%@.s3.amazonaws.com/%@"

#define STRING_S3_BADCONNECTION		@"Could not establish connection."
#define STRING_S3_MISSINGPARAMS		@"Missing parameters required for this operation."
#define STRING_S3_BADPATH			@"Could not open file."
#define STRING_S3_HTTPERROR			@"There was a problem with the request."

@interface S3Connection () <NSURLConnectionDelegate>
{
	NSURLConnection *connection;
	NSInteger statusCode;
	NSMutableData *responseData;
}

@property (nonatomic, copy) S3CompletionHandler completionHandler;

- (NSString *)authorizationHeader:(NSString *)verb withMD5:(NSString *)md5 contentType:(NSString *)contentType date:(NSString *)date resource:(NSString *)resource;
- (NSString *)dateHeader;

@end

@implementation S3Connection

- (id)initWithAccessKeyId:(NSString *)accessKeyId secretAccessKey:(NSString *)secretAccessKey
{
	if(self = [super init])
	{
		self.accessKeyId = accessKeyId;
		self.secretAccessKey = secretAccessKey;
	}
	return self;
}

- (void)dealloc
{
	[connection cancel];
	connection = nil;
	if(responseData)
	{
		[responseData release];
		responseData = nil;
	}
	self.accessKeyId = nil;
	self.secretAccessKey = nil;
	self.bucket = nil;
	self.completionHandler = nil;
	[super dealloc];
}

- (void)cancelCurrentRequest
{
	BOOL activeConnection = (connection != nil);
	[connection cancel];
	connection = nil;
	if(responseData)
	{
		[responseData release];
		responseData = nil;
	}
	if(activeConnection)
		[self release];
}

// http://docs.aws.amazon.com/AmazonS3/latest/dev/RESTAuthentication.html
- (NSString *)authorizationHeader:(NSString *)verb withMD5:(NSString *)md5 contentType:(NSString *)contentType date:(NSString *)date resource:(NSString *)resource
{
	NSString *signature;
	NSString *canonicalizedResource;
	NSString *stringToSign;
	CCHmacContext ctx;
	unsigned char hmac[20];
	
	if(!md5)
		md5 = @"";
	if(!contentType)
		contentType = @"";
	
	// Create the string to sign
	if([resource hasPrefix:@"/"])
		canonicalizedResource = [NSString stringWithFormat:@"/%@%@", _bucket, resource];
	else
		canonicalizedResource = [NSString stringWithFormat:@"/%@/%@", _bucket, resource];
	stringToSign = [NSString stringWithFormat:@"%@\n%@\n%@\n%@\n%@", verb, md5, contentType, date, canonicalizedResource];
	
	// Create the signature
	CCHmacInit(&ctx, kCCHmacAlgSHA1, [_secretAccessKey UTF8String], [_secretAccessKey length]);
	CCHmacUpdate(&ctx, [stringToSign UTF8String], [stringToSign length]);
	CCHmacFinal(&ctx, hmac);
	signature = [[NSData dataWithBytesNoCopy:hmac length:sizeof(hmac) freeWhenDone:NO] base64String];
	
	return [NSString stringWithFormat:@"AWS %@:%@", _accessKeyId, signature];
}

- (NSString *)dateHeader
{
	NSDateFormatter *dateFormatter;
	dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
	[dateFormatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss +0000"];
	[dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
	return [dateFormatter stringFromDate:[NSDate date]];
}

- (void)putData:(NSData *)data securely:(BOOL)securely withKey:(NSString *)key contentType:(NSString *)contentType completionHandler:(S3CompletionHandler)completionHandler
{
	NSURL *url;
	NSMutableURLRequest *request;
	NSString *md5;
	NSString *authorization;
	NSString *date;
	CC_MD5_CTX ctx;
	uint8_t hash[16];
	
	if(![data length] || ![key length])
	{
		if(completionHandler)
			completionHandler([NSError errorWithDomain:S3CONNECTION_ERROR_DOMAIN code:0 userInfo:@{NSLocalizedDescriptionKey:STRING_S3_MISSINGPARAMS}]);
		return;
	}
	
	[self retain];
	[self cancelCurrentRequest];
	
	// Calculate the MD5 and other headers
	CC_MD5_Init(&ctx);
	CC_MD5_Update(&ctx, [data bytes], [data length]);
	CC_MD5_Final(hash, &ctx);
	md5 = [[NSData dataWithBytesNoCopy:hash length:sizeof(hash) freeWhenDone:NO] base64String];
	date = [self dateHeader];
	authorization = [self authorizationHeader:@"PUT" withMD5:md5 contentType:contentType date:date resource:key];
	
	// Setup the request
	if(securely)
		url = [NSURL URLWithString:[NSString stringWithFormat:S3_SECURE_URL, _bucket, key]];
	else
		url = [NSURL URLWithString:[NSString stringWithFormat:S3_URL, _bucket, key]];
	request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:15.0];
	[request setHTTPMethod:@"PUT"];
	if([contentType length])
		[request addValue:contentType forHTTPHeaderField:@"Content-Type"];
	[request addValue:[NSString stringWithFormat:@"%u", [data length]] forHTTPHeaderField:@"Content-Length"];
	[request addValue:md5 forHTTPHeaderField:@"Content-MD5"];
	[request addValue:date forHTTPHeaderField:@"Date"];
	[request addValue:authorization forHTTPHeaderField:@"Authorization"];
	[request setHTTPBody:data];
	
	// Start the connection
	connection = [NSURLConnection connectionWithRequest:request delegate:self];
	if(connection != nil)
	{
		self.completionHandler = completionHandler;
	}
	else
	{
		if(completionHandler)
			completionHandler([NSError errorWithDomain:S3CONNECTION_ERROR_DOMAIN code:0 userInfo:@{NSLocalizedDescriptionKey:STRING_S3_BADCONNECTION}]);
		[self release];
	}
}

- (void)putFile:(NSString *)path securely:(BOOL)securely withKey:(NSString *)key completionHandler:(S3CompletionHandler)completionHandler
{
	NSInputStream *inputStream;
	NSURL *url;
	NSMutableURLRequest *request;
	NSString *extension, *contentType = nil;
	CFStringRef uti, mime;
	NSString *md5;
	NSString *authorization;
	NSString *date;
	CC_MD5_CTX ctx;
	uint8_t hash[16];
	uint8_t buf[1024];
	int len;
	size_t fileSize = 0;
	
	if(![path length] || ![key length])
	{
		if(completionHandler)
			completionHandler([NSError errorWithDomain:S3CONNECTION_ERROR_DOMAIN code:0 userInfo:@{NSLocalizedDescriptionKey:STRING_S3_MISSINGPARAMS}]);
		return;
	}
	
	inputStream = [NSInputStream inputStreamWithFileAtPath:path];
	if(!inputStream)
	{
		if(completionHandler)
			completionHandler([NSError errorWithDomain:S3CONNECTION_ERROR_DOMAIN code:0 userInfo:@{NSLocalizedDescriptionKey:STRING_S3_BADPATH}]);
		return;
	}
	
	[self retain];
	[self cancelCurrentRequest];
	
	// Determine the content type
	extension = [path pathExtension];
	if([extension length])
	{
		uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (CFStringRef)extension, NULL);
		if(uti)
		{
			mime = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType);
			if(mime)
			{
				contentType = [NSString stringWithString:(NSString *)mime];
				CFRelease(mime);
			}
			CFRelease(uti);
		}
	}
	
	// Calculate the MD5 and other headers
	CC_MD5_Init(&ctx);
	[inputStream open];
	while((len = [inputStream read:buf maxLength:sizeof(buf)]) > 0)
	{
		CC_MD5_Update(&ctx, buf, len);
		fileSize += len;
	}
	[inputStream close];
	CC_MD5_Final(hash, &ctx);
	md5 = [[NSData dataWithBytesNoCopy:hash length:sizeof(hash) freeWhenDone:NO] base64String];
	date = [self dateHeader];
	authorization = [self authorizationHeader:@"PUT" withMD5:md5 contentType:contentType date:date resource:key];
	
	// Setup the request
	if(securely)
		url = [NSURL URLWithString:[NSString stringWithFormat:S3_SECURE_URL, _bucket, key]];
	else
		url = [NSURL URLWithString:[NSString stringWithFormat:S3_URL, _bucket, key]];
	request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:15.0];
	[request setHTTPMethod:@"PUT"];
	if([contentType length])
		[request addValue:contentType forHTTPHeaderField:@"Content-Type"];
	[request addValue:[NSString stringWithFormat:@"%lu", fileSize] forHTTPHeaderField:@"Content-Length"];
	[request addValue:md5 forHTTPHeaderField:@"Content-MD5"];
	[request addValue:date forHTTPHeaderField:@"Date"];
	[request addValue:authorization forHTTPHeaderField:@"Authorization"];
	[request setHTTPBodyStream:[NSInputStream inputStreamWithFileAtPath:path]];
	
	// Setup the connection
	connection = [NSURLConnection connectionWithRequest:request delegate:self];
	if(connection != nil)
	{
		self.completionHandler = completionHandler;
	}
	else
	{
		if(completionHandler)
			completionHandler([NSError errorWithDomain:S3CONNECTION_ERROR_DOMAIN code:0 userInfo:@{NSLocalizedDescriptionKey:STRING_S3_BADCONNECTION}]);
		[self release];
	}
}

+ (void)uploadData:(NSData *)data securely:(BOOL)securely intoBucket:(NSString *)bucket withKey:(NSString *)key contentType:(NSString *)contentType accessKeyId:(NSString *)accessKeyId secretAccessKey:(NSString *)secretAccessKey completionHandler:(S3CompletionHandler)completionHandler
{
	S3Connection *s3connection;
	s3connection = [[[S3Connection alloc] initWithAccessKeyId:accessKeyId secretAccessKey:secretAccessKey] autorelease];
	s3connection.bucket = bucket;
	[s3connection putData:data securely:securely withKey:key contentType:contentType completionHandler:completionHandler];
}

+ (void)uploadFile:(NSString *)path securely:(BOOL)securely intoBucket:(NSString *)bucket withKey:(NSString *)key accessKeyId:(NSString *)accessKeyId secretAccessKey:(NSString *)secretAccessKey completionHandler:(S3CompletionHandler)completionHandler
{
	S3Connection *s3connection;
	s3connection = [[[S3Connection alloc] initWithAccessKeyId:accessKeyId secretAccessKey:secretAccessKey] autorelease];
	s3connection.bucket = bucket;
	[s3connection putFile:path securely:securely withKey:key completionHandler:completionHandler];
}

#pragma mark - NSURLConnectionDelegate methods

- (void)connection:(NSURLConnection *)theConnection didReceiveResponse:(NSURLResponse *)response
{
	statusCode = [(NSHTTPURLResponse *)response statusCode];
	if(statusCode != 200)
		responseData = [[NSMutableData alloc] init];
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)data
{
	if(responseData)
		[responseData appendData:data];
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	connection = nil;
	if(responseData)
	{
		[responseData release];
		responseData = nil;
	}
	if(_completionHandler)
		_completionHandler(error);
	[self release];
}

- (BOOL)connection:(NSURLConnection *)theConnection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace
{
	return [protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust];
}

- (void)connection:(NSURLConnection *)theConnection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
	if([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust])
		[challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge];
	[challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection
{
	connection = nil;
	if(statusCode != 200)
	{
		NSString *message = nil;
		NSString *response = [[[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding] autorelease];
		NSRange start, end;
		start = [response rangeOfString:@"<message>" options:NSCaseInsensitiveSearch];
		end = [response rangeOfString:@"</message>" options:NSCaseInsensitiveSearch];
		if(start.location != NSNotFound && end.location != NSNotFound)
			message = [response substringWithRange:NSMakeRange(start.location + start.length, end.location - (start.location + start.length))];
		[responseData release];
		responseData = nil;
		if(_completionHandler)
			_completionHandler([NSError errorWithDomain:S3CONNECTION_ERROR_DOMAIN code:statusCode userInfo:@{NSLocalizedDescriptionKey:message?message:STRING_S3_HTTPERROR}]);
	}
	else if(_completionHandler)
	{
		_completionHandler(nil);
	}
	[self release];
}

@end
