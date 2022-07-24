//
//  Topic.m
//  Mac TwitterBB
//
//  Created by Maxwell on 29/06/21.
//

#import "Topic.h"

@implementation Topic

+ (NSArray<Topic *> *)buildFromArray:(NSArray<NSDictionary *> *)array {
    NSMutableArray<Topic *> *finalTopics = [NSMutableArray new];
    NSMutableArray *tweets = [NSMutableArray new];
    NSMutableDictionary *topics = [NSMutableDictionary new];
    [array enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        Tweet *tweet = [[Tweet alloc] initWithDictionary:obj];
        [tweets addObject:tweet];
        [self addTopicTags:topics tags:tweet.topicTags];
    }];
    
    // FIXME: 1st, group replies to the same thread together
    // FIXME: 2nd, show a popover to the right when you select a tweet, with a webview of the tweet in it? Or just render the content myself?
    
    while (tweets.count > 0 && topics.count > 0) {
        __block NSString *biggestTag;
        __block int biggestCount = 0;
        [topics enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSNumber *obj, BOOL * _Nonnull stop) {
            if (obj.intValue > biggestCount) {
                biggestTag = key;
                biggestCount = obj.intValue;
            }
        }];
        [topics removeObjectForKey:biggestTag];
        
        NSMutableArray *biggestTweets = [NSMutableArray new];
        __block NSString *tagType;
        [tweets enumerateObjectsUsingBlock:^(Tweet *obj, NSUInteger idx, BOOL * _Nonnull stop) {
            int ix = [obj.topicTags indexOfObject:biggestTag];
            if (ix >= 0) {
                [biggestTweets addObject:obj];
                tagType = obj.topicTypes[ix];
            }
        }];
        if (biggestTweets.count > 1) {
            [biggestTweets enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                [tweets removeObject:obj];
            }];
            [finalTopics addObject:[[Topic alloc] initWithTitle:biggestTag topicType:tagType tweets:biggestTweets]];
        }
    }
    
    return finalTopics;
}

+ (void)addTopicTags:(NSMutableDictionary<NSString *, NSNumber *> *)topics tags:(NSArray<NSString *> *)tags {
    [tags enumerateObjectsUsingBlock:^(NSString * _Nonnull tag, NSUInteger idx, BOOL * _Nonnull stop) {
        NSNumber *existingTags = topics[tag];
        if (existingTags == nil) {
            existingTags = @1;
        } else {
            existingTags = @(existingTags.intValue + 1);
        }
        topics[tag] = existingTags;
    }];
}

- (instancetype)initWithTitle:(NSString *)title topicType:(NSString *)topicType tweets:(NSArray<Tweet *> *)tweets
{
    self = [super init];
    if (self) {
        _tweets = tweets;
        _title = title;
        _topicType = topicType;
        
        __block int topCount = 0;
        __block NSString *topNoun = nil;
        NSMutableDictionary<NSString *, NSNumber *> *topNouns = [NSMutableDictionary new];
        [_tweets enumerateObjectsUsingBlock:^(Tweet * _Nonnull tweet, NSUInteger idx, BOOL * _Nonnull stop) {
            
            [tweet.nouns enumerateObjectsUsingBlock:^(id  _Nonnull obj, BOOL * _Nonnull stop) {
                NSInteger count = [tweet.nouns countForObject:obj];
                NSNumber *existingTags = topNouns[obj];
                if (existingTags == nil) {
                    // Two ways to do this, i can either look at the overall count of words, or just occurances of tweets with the same word. Comment @1 to just check how many tweets shared words.
                    // FIXME: Maybe use overall count as a tie breaker!
                    existingTags = @1;
//                    existingTags = @(count);
                } else {
                    existingTags = @(existingTags.intValue + 1);
//                    existingTags = @(existingTags.intValue + count);
                }
                topNouns[obj] = existingTags;
                
                if (existingTags.intValue > topCount) {
                    topNoun = obj;
                    topCount = existingTags.intValue;
                }
            }];
        }];
        
        if (topNoun != nil && topCount > 1) {
            _noun = topNoun;
        }
    }
    return self;
}

@end
