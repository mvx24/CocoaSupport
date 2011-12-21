//
//  ClientLogin.m
//
//  Created by Marc on 11/18/11.
//  Copyright 2011 Symbiotic Software LLC. All rights reserved.
//

#import "ClientLogin.h"

@implementation ClientLogin

@synthesize target;
@synthesize action;
@synthesize success;
@synthesize result;
@synthesize userInfo;

- (id)initWithTarget:(id)theTarget selector:(SEL)theAction
{
	self = [super init];
	if (self)
	{
		self.target = theTarget;
		self.action = theAction;
	}
	return self;
}

- (void)dealloc
{
	[loginConnection cancel];
	loginConnection = nil;
	[loginData release];
	loginData = nil;
	[result release];
	result = nil;
	[super dealloc];
}

- (void)performLogin:(NSString *)username withPassword:(NSString *)password forApp:(NSString *)app
{
	NSString *body;
	NSURL *url;
	NSMutableURLRequest *request;
	
	if((self.target == nil) || (self.action == nil))
	{
		success = NO;
		result = [@"No target or action specified." retain];
		return;
	}
	
	if((username == nil) || (password == nil))
	{
		success = NO;
		result = [@"Missing username or password." retain];
		if((self.target != nil) && [self.target respondsToSelector:self.action])
			[self.target performSelector:self.action withObject:self];
		return;
	}

	if(app == nil)
		app = @"ClientLoginApp";
	
	body = [NSString stringWithFormat:@"accountType=GOOGLE&Email=%@&Passwd=%@&service=fusiontables&source=%@", username, password, app];
	url = [NSURL URLWithString:@"https://www.google.com/accounts/ClientLogin"];
	request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:15.0];
	[request setHTTPMethod:@"POST"];
	[request addValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
	[request setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];
	loginConnection = [NSURLConnection connectionWithRequest:request delegate:self];
	if(loginConnection != nil)
	{
		loginData = [[NSMutableData data] retain];
		[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
	}
	
}

- (void)cancel
{
	[loginConnection cancel];
	loginConnection = nil;
	[loginData release];
	loginData = nil;
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
}

/*-------------------------------------------------------------------*/
#pragma mark -
#pragma mark NSURLConnection delegate methods

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	[loginData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	[loginData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{	
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
	
	[loginData release];
	loginData = nil;
	loginConnection = nil;
	success = NO;
	result = [[error localizedFailureReason] retain];
	
	if((self.target != nil) && [self.target respondsToSelector:self.action])
		[self.target performSelector:self.action withObject:self];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	NSString *responseStr;
	NSArray *components;
	
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];

	responseStr = [[[NSString alloc] initWithData:loginData encoding:NSUTF8StringEncoding] autorelease];
	components = [responseStr componentsSeparatedByString:@"\n"];
	success = NO;
	for(NSString *line in components)
	{
		if([line hasPrefix:@"Auth="])
		{
			success = YES;
			result = [[line substringFromIndex:5] retain];
			break;
		}
	}
	if(!success)
		result = [@"Username or password incorrect." retain];
	loginConnection = nil;
	[loginData release];
	loginData = nil;
	
	if((self.target != nil) && [self.target respondsToSelector:self.action])
		[self.target performSelector:self.action withObject:self];
}

@end
