//
//  CSVParser.m
//
//  Created by Marc on 10/30/11.
//  Copyright 2011 Symbiotic Software LLC. All rights reserved.
//

#import "CSVParser.h"

@interface CSVParser (PrivateMethods)

- (void)setColumnNumber:(NSUInteger)number;

@end

@implementation CSVParser (PrivateMethods)

- (void)setColumnNumber:(NSUInteger)number
{
	columnNumber = number;
}

@end

BOOL processCSVLine(const char *csvLine, BOOL (*processField)(const char *, unsigned int, void *), void * data, int requiredFields)
{
	char *ptr, *startPtr, *endPtr, *newEndPtr;
	BOOL quotes = NO;
	unsigned int field = 0;
	unsigned int len = strlen(csvLine);
	char *lineCopy;
	
	// Allocate a copy buffer that is double the size of the string
	lineCopy = (char *)malloc(sizeof(char) * ((len + 1) * 2));
	if(lineCopy == NULL) return NO;
	strncpy(lineCopy, csvLine, sizeof(char) * ((len + 1) * 2));
	
	for(startPtr = endPtr = lineCopy; *endPtr; ++endPtr)
	{
		if(*endPtr == '"')
		{
			if(quotes)
			{
				if(*(endPtr + 1) != '"')
				{
					quotes = NO;
				}
				else
				{
					for(ptr = endPtr; *ptr; ++ptr)
						*ptr = *(ptr + 1);
				}
				continue;
			}
			else
			{
				quotes = YES;
			}
		}
		else if((*endPtr == ',') && (quotes == NO))
		{
			*endPtr = 0;
			// Skip leading and trailing whitespace
			while((*startPtr == ' ') || (*startPtr == '\t')) ++startPtr;
			if(startPtr != endPtr)
				newEndPtr = endPtr - 1;
			else
				newEndPtr = endPtr;
			while((*newEndPtr == ' ') || (*newEndPtr == '\t')) --newEndPtr;
			if((*startPtr == '"') && (*newEndPtr == '"'))
			{
				*newEndPtr = 0;
				if(processField(startPtr + 1, field++, data) == NO)
					return NO;
				*newEndPtr = '"';
			}
			else
			{
				if(processField(startPtr, field++, data) == NO)
					return NO;
			}
			*endPtr = ',';
			startPtr = endPtr + 1;
		}
	}
	// Process the last field, skipping leading and trailing whitespace
	while((*startPtr == ' ') || (*startPtr == '\t')) ++startPtr;
	if(startPtr != endPtr)
		newEndPtr = endPtr - 1;
	else
		newEndPtr = endPtr;
	while((*newEndPtr == ' ') || (*newEndPtr == '\t')) --newEndPtr;
	if((*startPtr == '"') && (*newEndPtr == '"'))
	{
		*newEndPtr = 0;
		if(processField(startPtr + 1, field++, data) == NO)
			return NO;
		*newEndPtr = '"';
	}
	else
	{
		if(processField(startPtr, field++, data) == NO)
			return NO;
	}
	free(lineCopy);
	// If at the end of the record and still in quotes then this is a format error
	if(quotes)
		return NO;
	// Return YES if the record was complete according to the requirement
	if(requiredFields)
		return (field == requiredFields);
	
	return YES;
}

BOOL csvParserProcessField(const char *value, unsigned int column, void *csvParser)
{
	CSVParser *parser = (CSVParser *)csvParser;
	NSString *stringValue;
	
	[parser setColumnNumber:column];
	if([(NSObject *)parser.delegate respondsToSelector:@selector(parser:didParseValue:)])
	{
		stringValue = [[NSString alloc] initWithBytes:value length:strlen(value) encoding:NSUTF8StringEncoding];
		[parser.delegate parser:parser didParseValue:stringValue];
	}
	return YES;
}

@implementation CSVParser

@synthesize delegate;

- (id)initWithString:(NSString *)csvDocument
{
	if(self = [super init])
	{
		csv = [csvDocument retain];
	}
	return self;
}

- (void)dealloc
{
	[csv release];
	[columnNames release];
	[super dealloc];
}

- (void)parse
{
	NSArray *csvLines = nil;

	if(self.delegate != nil)
	{
		if(![csv length])
		{
			if([(NSObject *)self.delegate respondsToSelector:@selector(parser:parseErrorOccurred:)])
				[self.delegate parser:self parseErrorOccurred:[NSError errorWithDomain:CSV_DOMAIN code:CSV_ERROR_NODATA userInfo:nil]];
			return;
		}
		
		[line release];
		line = nil;
		lineNumber = 0;
		if([(NSObject *)self.delegate respondsToSelector:@selector(parserDidStartDocument:)])
			[self.delegate parserDidStartDocument:self];
		
		// Start of parsing
		NSRange range = [csv rangeOfString:@"\n"];
		if((range.location != NSNotFound) && (range.location > 0))
		{
			if([csv characterAtIndex:(range.location - 1)] == '\r')
				csvLines = [csv componentsSeparatedByString:@"\r\n"];
		}
		if(csvLines == nil)
			csvLines = [csv componentsSeparatedByString:@"\n"];
		
		// Parsing
		for(NSString *csvLine in csvLines)
		{
			line = csvLine;
			if(expectHeaders && (columnNames == nil))
			{
				id <CSVParserDelegate> parserDelegate = delegate;
				// Parse the first line to retrieve the headers
				delegate = (id<CSVParserDelegate>)self;
				columnNames = [NSMutableArray array];
				if(!processCSVLine([line UTF8String], csvParserProcessField, self, 0))
				{
					delegate = parserDelegate;
					if([(NSObject *)delegate respondsToSelector:@selector(parser:parseErrorOccurred:)])
						[delegate parser:self parseErrorOccurred:[NSError errorWithDomain:CSV_DOMAIN code:CSV_ERROR_BADFORMAT userInfo:nil]];
					line = nil;
					return;
				}
				if(expectedColumnsCount && ([columnNames count] != expectedColumnsCount))
				{
					delegate = parserDelegate;
					if([(NSObject *)delegate respondsToSelector:@selector(parser:parseErrorOccurred:)])
						[delegate parser:self parseErrorOccurred:[NSError errorWithDomain:CSV_DOMAIN code:CSV_ERROR_BADHEADER userInfo:nil]];
					line = nil;
					return;
				}
				// Restore the delegate and count the columns
				delegate = parserDelegate;
				columnNames = [[NSArray arrayWithArray:columnNames] retain];
				expectedColumnsCount = [columnNames count];
			}
			else
			{
				if([(NSObject *)self.delegate respondsToSelector:@selector(parserDidStartLine:)])
					[self.delegate parserDidStartLine:self];
				if(!processCSVLine([line UTF8String], csvParserProcessField, self, expectedColumnsCount))
				{
					if([(NSObject *)self.delegate respondsToSelector:@selector(parser:parseErrorOccurred:)])
						[self.delegate parser:self parseErrorOccurred:[NSError errorWithDomain:CSV_DOMAIN code:CSV_ERROR_BADFORMAT userInfo:nil]];
					line = nil;
					return;
				}
				if([(NSObject *)self.delegate respondsToSelector:@selector(parserDidEndLine:)])
					[self.delegate parserDidEndLine:self];
				++lineNumber;
			}
		}
		
		// End of parsing
		if([(NSObject *)self.delegate respondsToSelector:@selector(parserDidEndDocument:)])
			[self.delegate parserDidEndDocument:self];
		
		//Cleanup
		[columnNames release];
		columnNames = nil;
		line = nil;
		lineNumber = 0;
	}
}

- (void)setExpectedColumnsCount:(NSUInteger)expected
{
	expectedColumnsCount = expected;
}

- (void)setIsExpectingColumnsHeader:(BOOL)expecting
{
	expectHeaders = expecting;
}

- (NSArray *)columnNames
{
	return columnNames;
}

- (NSString *)line
{
	return line;
}

- (NSInteger)lineNumber
{
	return lineNumber;
}

- (NSInteger)columnNumber
{
	return columnNumber;
}

- (void)parser:(CSVParser *)parser didParseValue:(NSString *)value
{
	[(NSMutableArray *)columnNames addObject:value];
}

@end
