//
//  NSStringAddition.m
//
//  Copyright 2011 Symbiotic Software LLC. All rights reserved.
//

#import "NSStringAddition.h"
#include <stdlib.h>

@implementation NSString (Addition)

- (NSString *)stringByEscapingForXML
{
	NSMutableString *str;
	
	// TODO: make more complete
	str = [[self mutableCopy] autorelease];
	[str replaceOccurrencesOfString:@"&" withString:@"&amp;" options:NSLiteralSearch range:NSMakeRange(0, [str length])];
	[str replaceOccurrencesOfString:@"<" withString:@"&lt;" options:NSLiteralSearch range:NSMakeRange(0, [str length])];
	[str replaceOccurrencesOfString:@">" withString:@"&gt;" options:NSLiteralSearch range:NSMakeRange(0, [str length])];
	
	return str;
}

- (NSString *)stringByEscapingForCSV
{
	NSRange range;
	
	range = [self rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\"\r\n,"]];
	if(range.location != NSNotFound)
	{
		NSMutableString *str;
		str = [[self mutableCopy] autorelease];
		/* Make all double quotes, double double quotes */
		[str replaceOccurrencesOfString:@"\"" withString:@"\"\"" options:NSLiteralSearch range:NSMakeRange(0, [str length])];
		/* Quote the entire field */
		[str insertString:@"\"" atIndex:0];
		[str appendString:@"\""];
		return str;
	}
	return self;
}

- (NSString *)stringByEscapingForURLQuery
{
	return [self stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet];
/*
	NSString *result = (NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)self, NULL, CFSTR("!*'();:@&=$,/?#^[]+\"{}<>`\\ "), kCFStringEncodingUTF8);
	return [result autorelease];
*/
/*
	NSMutableString *str;
	NSRange range;
	NSCharacterSet *escapeSet;
	unichar c;
	
	str = [[self mutableCopy] autorelease];
	escapeSet = [NSCharacterSet characterSetWithCharactersInString:@"!*'();:@&=$,/?#^[]+\"{}<>`\\ "];
	// First replace all of the % so that % escaping can be used undisturbed
	[str replaceOccurrencesOfString:@"%" withString:@"%25" options:NSLiteralSearch range:NSMakeRange(0, [str length])];
	
	while(1)
	{		
		range = [str rangeOfCharacterFromSet:escapeSet];
		if(range.location != NSNotFound)
		{
			c = [str characterAtIndex:range.location];
			[str replaceOccurrencesOfString:[NSString stringWithFormat:@"%c", c] withString:[NSString stringWithFormat:@"%%%02X", c] options:NSLiteralSearch range:NSMakeRange(0, [str length])];
		}
		else
		{
			break;
		}
	}
	
	return str;
*/
}

- (NSString *)stringByCapitalizingFirstCharacter
{
	NSString *firstChar, *str;
	
	firstChar = [self substringToIndex:1];
	str = [self substringFromIndex:1];
	return [[firstChar uppercaseString] stringByAppendingString:str];
}

- (NSString *)stringByDecapitalizingFirstCharacter
{
	NSString *firstChar, *str;
	
	firstChar = [self substringToIndex:1];
	str = [self substringFromIndex:1];
	return [[firstChar lowercaseString] stringByAppendingString:str];
}

+ (id)stringWithHexString:(NSString *)hexString
{
	NSMutableString *unhexString;
	char hexChar[3] = {0};
	const char *bytes;
	size_t i, length;
	
	length = [hexString length];
	if(!length)
		return [NSString string];
	
	bytes = [hexString UTF8String];
	unhexString = [NSMutableString stringWithCapacity:[hexString length]/2];
	for(i = 0; i < length; i += 2)
	{
		hexChar[0] = bytes[i];
		hexChar[1] = bytes[i+1];
		[unhexString appendFormat:@"%c", (char)strtol(hexChar, NULL, 16)];
	}
	return [NSString stringWithString:unhexString];
}

- (NSString *)hexString
{
	NSMutableString *hexString;
	const char *bytes;
	size_t i, length;
	
	length = [self length];
	if(!length)
		return [NSString string];
	
	bytes = [self UTF8String];
	hexString = [NSMutableString stringWithCapacity:length * 2];
	for(i = 0; i < length; ++i)
		[hexString appendFormat:@"%02x", *(bytes + i)];
	return [NSString stringWithString:hexString];
}

// This gets invoked instead of boolValue for key-values.
// Use full strings such as "true" or "false" to avoid return 'f' for false
- (char)charValue
{
	if([self length] > 1)
		return [self boolValue];
	else
		return (char)[self characterAtIndex:0];
}

- (NSUInteger)unsignedIntegerValue
{
	return (NSUInteger)strtoul([self UTF8String], NULL, 10);
}

- (unsigned int)unsignedIntValue
{
	return (unsigned int)strtoul([self UTF8String], NULL, 10);
}

- (unsigned long long)unsignedLongLongValue
{
	return strtoull([self UTF8String], NULL, 10);
}

@end
