//
//  ClientLogin.h
//
//  Copyright 2013 Symbiotic Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ClientLogin : NSObject
{
@private
	id target;
	SEL action;
	BOOL success;
	NSString *result;
	NSURLConnection *loginConnection;
	NSMutableData *loginData;
}

@property (nonatomic, assign) id target;
@property (nonatomic, assign) SEL action;
@property (nonatomic, assign) BOOL success;
@property (nonatomic, readonly) NSString *result;
@property (nonatomic, assign) id userInfo;

- (id)initWithTarget:(id)theTarget selector:(SEL)theAction;
- (void)performLogin:(NSString *)username withPassword:(NSString *)password forApp:(NSString *)app;
- (void)cancel;

@end
