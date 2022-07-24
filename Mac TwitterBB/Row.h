//
//  Row.h
//  Mac TwitterBB
//
//  Created by Maxwell on 28/06/21.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface Row : NSTableCellView

@property (weak) IBOutlet NSTextField *author;
@property (weak) IBOutlet NSTextField *time;
@property (weak) IBOutlet NSTextField *content;

@end

NS_ASSUME_NONNULL_END
