//
//  NSDataAddition.m
//
//  Copyright 2012 Symbiotic Software LLC. All rights reserved.
//

#import "NSDataAddition.h"

@implementation NSData (Addition)

- (BOOL)isXML
{
	const char *ptr;
	
	for(ptr = [self bytes]; (*ptr == ' ') || (*ptr == '\t') || (*ptr == '\n') || (*ptr == '\r'); ++ptr);
	return (strncmp(ptr, "<?xml", 5) == 0);
}

// Sterilize the data to remove any leading whitespace
- (NSData *)XMLData
{
	const char *ptr;
	size_t length;
	
	length = [self length];
	for(ptr = [self bytes]; (*ptr == ' ') || (*ptr == '\t') || (*ptr == '\n') || (*ptr == '\r'); ++ptr, --length);
	if(strncmp(ptr, "<?xml", 5) == 0)
		return [NSData dataWithBytesNoCopy:(void *)ptr length:length freeWhenDone:NO];
	return nil;
}

- (NSString *)hexString
{
	NSMutableString *hexString;
	const unsigned char *bytes;
	size_t i, length;
	
	length = [self length];
	if(!length)
		return [NSString string];
	
	bytes = [self bytes];
	hexString = [NSMutableString stringWithCapacity:length * 2];
	for(i = 0; i < length; ++i)
		[hexString appendFormat:@"%02x", *(bytes + i)];
	return [NSString stringWithString:hexString];
}

@end
