//
//  NSStringAddition.h
//
//  Copyright 2011 Symbiotic Software LLC. All rights reserved.
//

@interface NSString (Addition)

- (NSString *)stringByEscapingForXML;
- (NSString *)stringByEscapingForCSV;
- (NSString *)stringByEscapingForURLQuery;
- (NSString *)stringByCapitalizingFirstCharacter;
- (NSString *)stringByDecapitalizingFirstCharacter;
+ (id)stringWithHexString:(NSString *)hexString;
- (NSString *)hexString;

- (char)charValue;
- (NSUInteger)unsignedIntegerValue;
- (unsigned int)unsignedIntValue;
- (unsigned long long)unsignedLongLongValue;

@end
