//
//  ViewController.m
//  Mac TwitterBB
//
//  Created by Maxwell on 28/06/21.
//

#import "ViewController.h"
#import <AuthenticationServices/AuthenticationServices.h>
#import "TwitterBB-Swift.h"
#import "Row.h"
#import "Topic.h"
#import <WebKit/WebKit.h>

@interface ViewController () <ASWebAuthenticationPresentationContextProviding, NSOutlineViewDelegate, NSOutlineViewDataSource>

@property TwitterService *service;

@property (weak) IBOutlet NSOutlineView *outlineView;

@property NSArray<Topic *> *topics;

@property NSPopover *popover;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.outlineView.delegate = self;
    self.outlineView.dataSource = self;
    self.outlineView.target = self;
    self.outlineView.action = @selector(clickARow:);
}

- (void)viewDidAppear {
    [super viewDidAppear];
    
    self.service = [[TwitterService alloc] init];
    self.service.viewController = self;
    self.service.context = self;
    
    [self setRepresentedObject: [[NSUserDefaults standardUserDefaults] objectForKey:@"cache"]];
    
}

- (void)refresh:(id)sender {
    
    [self.service authorize];
}

- (void)setTweetData:(NSArray *)tweets {
    
    [[NSUserDefaults standardUserDefaults] setObject:[NSJSONSerialization dataWithJSONObject:tweets options:0 error:nil] forKey:@"cache"];
    
    
    [self setRepresentedObject: [[NSUserDefaults standardUserDefaults] objectForKey:@"cache"]];
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    if (representedObject != nil) {
        NSArray *tweets = [NSJSONSerialization JSONObjectWithData:self.representedObject options:0 error:nil];
        
        self.topics = [Topic buildFromArray:tweets];
        [self.outlineView reloadData];
        [self.outlineView expandItem:nil expandChildren:YES];
    }
}

- (ASPresentationAnchor)presentationAnchorForWebAuthenticationSession:(ASWebAuthenticationSession *)session {
    return self.view.window;
}

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    Row *view;
    if ([item isKindOfClass:[Topic class]]) {
        view = [outlineView makeViewWithIdentifier:@"header" owner:self];
        if ([item noun]) {
            if ([[item topicType] isEqual:NSLinguisticTagPlaceName]) {
                view.content.stringValue = [NSString stringWithFormat:@"%@ in %@", [item noun], [item title]];
            } else {
                view.content.stringValue = [NSString stringWithFormat:@"%@'s %@", [item title], [item noun]];
            }
        } else {
            view.content.stringValue = [item title];
        }
    } else {
        view = [outlineView makeViewWithIdentifier:@"tweet" owner:self];
        view.content.stringValue = [item content];
        view.time.stringValue = [item timeString];
        view.author.stringValue = [item authorString];
    }
    return view;
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(nullable id)item {
    if (item == nil) {
        return self.topics.count;
    } else {
        Topic *topic = item;
        return topic.tweets.count;
    }
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(nullable id)item {
    if (item == nil) {
        return self.topics[index];
    } else {
        Topic *topic = item;
        return topic.tweets[index];
    }
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    return [item isKindOfClass:[Topic class]];
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
    [self.popover close];
    self.popover = nil;
    NSInteger idx = [self.outlineView selectedRow];
    
    if (idx >= 0) {
        id item = [self.outlineView itemAtRow:idx];
        if ([item isKindOfClass:[Tweet class]]) {
            
            self.popover = [NSPopover new];
            
            WKWebView *view = [[WKWebView alloc] init];
            [view loadRequest:[NSURLRequest requestWithURL:[item URL]]];
            NSViewController *vc = [[NSViewController alloc] initWithNibName:nil bundle:nil];
            CGRect frame = CGRectMake(0, 0, 536, 656);
            [view setTranslatesAutoresizingMaskIntoConstraints:NO];
            
            vc.view = view;
            view.frame = frame;
            vc.preferredContentSize = frame.size;
            self.popover.contentViewController = vc;
            self.popover.animates = NO;
            NSView *row = [self.outlineView viewAtColumn:0 row:idx makeIfNecessary:NO];
            [self.popover showRelativeToRect:CGRectZero ofView:row preferredEdge:NSMaxXEdge];
        }
    }
}

- (void)clickARow:(id)sender {
    NSInteger idx = [self.outlineView selectedRow];
    
    if (idx >= 0) {
        
        id item = [self.outlineView itemAtRow:idx];
        if ([item isKindOfClass:[Topic class]]) {
            if ([self.outlineView isItemExpanded:item]) {
                [self.outlineView collapseItem:item];
            } else {
                [self.outlineView expandItem:item];
            }
        }
    }
    
}

@end
