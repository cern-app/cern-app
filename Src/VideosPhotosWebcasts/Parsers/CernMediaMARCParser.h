//  The initial version by Eamon Ford on 6/25/12.

#import <Foundation/Foundation.h>


@class CernMediaMARCParser;

@protocol CernMediaMarcParserDelegate <NSObject>
@required
- (void) parser : (CernMediaMARCParser *) parser didParseRecord : (NSDictionary *) record;
- (void) parserDidFinish : (CernMediaMARCParser *) parser;
- (void) parser : (CernMediaMARCParser *) parser didFailWithError : (NSError *) error;
@end

@interface CernMediaMARCParser : NSObject<NSURLConnectionDelegate, NSXMLParserDelegate>

@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) NSArray *resourceTypes;
@property (nonatomic) __weak id<CernMediaMarcParserDelegate> delegate;

- (void) parse;
- (void) stop;

@end
