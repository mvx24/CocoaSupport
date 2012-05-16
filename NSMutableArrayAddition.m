//
//  NSMutableArrayAddition.m
//
//  Copyright 2009 Symbiotic Software LLC. All rights reserved.
//

#import "NSMutableArrayAddition.h"

@implementation NSMutableArray (Addition)

- (void)pushObject:(id)anObject
{
	[self addObject:anObject];
}

- (id)popObject
{
	id ret;
	if([self count])
	{
		ret = [[self lastObject] retain];
		[self removeLastObject];
		[ret autorelease];
		return ret;
	}
	else
	{
		return nil;
	}
}

- (void)pushFrontObject:(id)anObject
{
	[self insertObject:anObject atIndex:0];
}

- (id)popFrontObject
{
	id ret;
	if([self count])
	{
		ret = [[self objectAtIndex:0] retain];
		[self removeObjectAtIndex:0];
		[ret autorelease];
		return ret;
	}
	else
	{
		return nil;
	}
}

@end
