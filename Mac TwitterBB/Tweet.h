//
//  Tweet.h
//  Mac TwitterBB
//
//  Created by Maxwell on 29/06/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Tweet : NSObject

- (instancetype)initWithDictionary:(NSDictionary *)dictionary;

@property NSString *content;
@property NSArray<NSString *> *topicTags;
@property NSArray<NSString *> *topicTypes;
@property NSCountedSet *nouns;
@property NSString *timeString;
@property NSString *authorString;
@property NSURL *URL;

@end

NS_ASSUME_NONNULL_END
