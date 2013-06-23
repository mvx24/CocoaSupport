//
//  NSDataAddition.h
//
//  Copyright 2012 Symbiotic Software LLC. All rights reserved.
//

@interface NSData (Addition)

- (BOOL)isXML;
- (NSData *)XMLData;
- (NSString *)hexString;
- (NSString *)base64String;
+ (NSData *)dataWithBase64String:(NSString *)base64String;

@end
