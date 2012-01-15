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

@end
