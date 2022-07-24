//
//  Topic.h
//  Mac TwitterBB
//
//  Created by Maxwell on 29/06/21.
//

#import <Foundation/Foundation.h>

#import "Tweet.h"

NS_ASSUME_NONNULL_BEGIN

@interface Topic : NSObject

+ (NSArray<Topic *> *)buildFromArray:(NSArray<NSDictionary *> *)array;

@property NSString *title;
@property NSString *topicType;
@property NSString *noun;
@property NSArray<Tweet *> *tweets;

@end

NS_ASSUME_NONNULL_END
