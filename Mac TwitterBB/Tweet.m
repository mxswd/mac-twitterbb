//
//  Tweet.m
//  Mac TwitterBB
//
//  Created by Maxwell on 29/06/21.
//

#import "Tweet.h"
#import <NaturalLanguage/NaturalLanguage.h>

@implementation Tweet

- (instancetype)initWithDictionary:(NSDictionary *)dictionary
{
    self = [super init];
    if (self) {
        _content = dictionary[@"text"];
        NSMutableArray *tags = [NSMutableArray new];
        NSMutableArray *types = [NSMutableArray new];
        NSCountedSet *nouns = [NSCountedSet new];
        
        NLTagger *tagger = [[NLTagger alloc] initWithTagSchemes:@[NLTagSchemeNameTypeOrLexicalClass]];
        tagger.string = _content;
        NSArray *goodTags = @[NLTagOrganizationName, NLTagPersonalName, NLTagPlaceName];
        NLTaggerOptions options = NLTaggerOmitPunctuation | NLTaggerOmitWhitespace | NLTaggerJoinNames;
        [tagger enumerateTagsInRange:NSMakeRange(0, _content.length) unit:(NLTokenUnitWord) scheme:NLTagSchemeNameTypeOrLexicalClass options:options usingBlock:^(NLTag  _Nullable tag, NSRange tokenRange, BOOL * _Nonnull stop) {
            if ([goodTags containsObject:tag]) {
                NSString *str = [_content substringWithRange:tokenRange];
//                NSLog(@"%@ - %@", tag, str);
                [tags addObject:str];
                [types addObject:tag];
            }
            if ([tag isEqual:NLTagNoun]) {
                NSString *str = [_content substringWithRange:tokenRange];
                if (![str isEqual:@"t.co"]) {
                    [nouns addObject:str];
                }
            }
        }];
        
        _nouns = nouns;
        _topicTags = tags;
        _topicTypes = types;
        
        _authorString = dictionary[@"user"][@"screen_name"];
        NSString *statusId = dictionary[@"id_str"];
        
        NSString *createdAt = dictionary[@"created_at"];
        NSDateFormatter *parser = [[NSDateFormatter alloc] init];
        NSTimeZone *timeZoneEDT = [NSTimeZone timeZoneWithName:@"GMT"];
        [parser setTimeZone:timeZoneEDT];
        [parser setDateFormat:@"E MMM d HH:mm:ss z yyyy"];
        NSDate *created = [parser dateFromString:createdAt];
        NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
        fmt.timeStyle = NSDateFormatterShortStyle;
        fmt.dateStyle = NSDateFormatterNoStyle;
        fmt.timeZone = [NSTimeZone localTimeZone];
        _timeString = [fmt stringFromDate:created];
        
        _URL = [NSURL URLWithString:[NSString stringWithFormat:@"https://twitter.com/%@/status/%@", _authorString, statusId]];
    }
    return self;
}

@end
