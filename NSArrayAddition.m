//
//  NSArrayAddition.m
//
//  Copyright 2012 Symbiotic Software LLC. All rights reserved.
//

#import "NSArrayAddition.h"

@implementation NSArray (Addition)

- (NSArray *)arrayByRemovingObject:(id)anObject
{
	NSUInteger index;
	NSRange range;
	
	if((index = [self indexOfObject:anObject]) != NSNotFound)
	{
		if([self count] == 1)
		{
			return [NSArray array];
		}
		else if(index == 0)
		{
			range.location = 1;
			range.length = [self count] - 1;
			return [self subarrayWithRange:range];
		}
		else if(index == ([self count] - 1))
		{
			range.location = 0;
			range.length = [self count] - 1;
			return [self subarrayWithRange:range];
		}
		else
		{
			NSArray *subarray1, *subarray2;
			range.location = 0;
			range.length = index;
			subarray1 = [self subarrayWithRange:range];
			range.location = index + 1;
			range.length = ([self count] - index) - 1;
			subarray2 = [self subarrayWithRange:range];
			return [subarray1 arrayByAddingObjectsFromArray:subarray2];
		}
	}
	return self;
}

@end
