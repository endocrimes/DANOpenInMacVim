//
//  DANOpenInMacVim.m
//  DANOpenInMacVim
//
//  Created by Daniel Tomlinson on 07/10/2015.
//  Copyright © 2015 Rocket Apps. All rights reserved.
//

#import "DANOpenInMacVim.h"
#import "DANXcodePrivate.h"

static DANOpenInMacVim *sharedPlugin;

@interface DANOpenInMacVim()

@property (nonatomic, strong, readwrite) NSBundle *bundle;
@property (nonatomic, assign) NSUInteger column;
@property (nonatomic, assign) NSUInteger row;

@end

@implementation DANOpenInMacVim

+ (void)pluginDidLoad:(NSBundle *)plugin {
    static id sharedPlugin = nil;
    static dispatch_once_t onceToken;
    NSString *currentApplicationName = [[NSBundle mainBundle] infoDictionary][@"CFBundleName"];
    if ([currentApplicationName isEqual:@"Xcode"]) {
        dispatch_once(&onceToken, ^{
            sharedPlugin = [[self alloc] initWithBundle:plugin];
        });
    }
}

+ (instancetype)sharedPlugin {
    return sharedPlugin;
}

- (id)initWithBundle:(NSBundle *)plugin {
    self = [super init];
    if (self) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setup];

            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textViewDidChangeNotification:)
                                                         name:NSTextViewDidChangeSelectionNotification object:nil];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textViewDidChangeNotification:)
                                                         name:NSTextDidChangeNotification object:nil];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textViewDidChangeNotification:)
                                                         name:NSTextDidBeginEditingNotification object:nil];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textViewDidChangeNotification:)
                                                         name:NSTextDidEndEditingNotification object:nil];
        });
    }
    
    return self;
}

#pragma -mark Listen Notification

- (void)textViewDidChangeNotification:(NSNotification *)noti {
    id firstResponder = [[NSApp keyWindow] firstResponder];

    if (![firstResponder isKindOfClass:NSClassFromString(@"DVTSourceTextView")]) return;

    NSTextView *textView = (NSTextView *)firstResponder;
    NSRange selectedRange = [textView selectedRange];
    NSString *viewContent = [textView string];

    NSRange lineRange = [viewContent lineRangeForRange:NSMakeRange(selectedRange.location,0)];
    NSUInteger column = selectedRange.location - lineRange.location;

    // Calculate current line number
    __block NSUInteger lineNumber = 0;
    [[viewContent substringToIndex:selectedRange.location] enumerateLinesUsingBlock:^(NSString * _Nonnull line, BOOL * _Nonnull stop) {
        ++lineNumber;
    }];

    self.row = lineNumber;
    self.column = column;
}

#pragma -mark Initialization
- (void)setup {
    // Add menu bar items for the 'Show Project in Finder' and 'Open Project in Terminal' actions
    NSMenu *fileMenu = [[[NSApp mainMenu] itemWithTitle:@"File"] submenu];
    NSInteger desiredMenuItemIndex = [fileMenu indexOfItemWithTitle:@"Open with External Editor"];
    
    if (fileMenu && (desiredMenuItemIndex >= 0)) {
        NSMenuItem *openWithExternalEditorMenuItem = [[NSMenuItem alloc] initWithTitle:@"Open File in MacVim" action:@selector(openInMacVim:) keyEquivalent:@"v"];
        [openWithExternalEditorMenuItem setTarget:self];
        [openWithExternalEditorMenuItem setKeyEquivalentModifierMask:NSCommandKeyMask | NSControlKeyMask];
        [fileMenu insertItem:openWithExternalEditorMenuItem atIndex:desiredMenuItemIndex];
    }
    else if ([NSApp mainMenu]) {
        NSLog(@"DANOpenInMacVim Xcode plugin: Couldn't find an 'Open with External Editor' item in the File menu");
    }
}

#pragma --mark Files
- (void)openInMacVim:(id)sender {
    NSURL *currentFileURL = [self currentProjectURL];
    if (currentFileURL) {
        NSString *cursor = [NSString stringWithFormat:@"+call cursor(%lu, %lu)", self.row, self.column];
        NSTask *task = [[NSTask alloc] init];
        task.launchPath = @"/usr/local/bin/gvim";
        task.arguments = @[ @"--servername", @"xcode", @"--remote-tab-silent", cursor, [currentFileURL path] ];
        [task launch];
    }
}

- (NSURL *)currentProjectURL {
    IDEFileNavigableItem *item = [[[self class] selectedSourceCodeFileNavigableItems] firstObject];
    
    return [item fileURL];
}

+ (NSArray *)selectedSourceCodeFileNavigableItems {
    NSMutableArray *mutableArray = [NSMutableArray array];
    id currentWindowController = [[NSApp keyWindow] windowController];
    
    if ([currentWindowController isKindOfClass:NSClassFromString(@"IDEWorkspaceWindowController")]) {
        IDEWorkspaceWindowController *workspaceController = currentWindowController;
        IDEWorkspaceTabController *workspaceTabController = [workspaceController activeWorkspaceTabController];
        IDENavigatorArea *navigatorArea = [workspaceTabController navigatorArea];
        id currentNavigator = [navigatorArea currentNavigator];
        
        if ([currentNavigator isKindOfClass:NSClassFromString(@"IDEStructureNavigator")]) {
            IDEStructureNavigator *structureNavigator = currentNavigator;
            
            for (id selectedObject in structureNavigator.selectedObjects) {
                NSArray *arrayOfFiles = [self recursivlyCollectFileNavigableItemsFrom:selectedObject];
                
                if ([arrayOfFiles count]) {
                    [mutableArray addObjectsFromArray:arrayOfFiles];
                }
            }
        }
    }
    
    if ([mutableArray count]) {
        return [NSArray arrayWithArray:mutableArray];
    }
    
    return nil;
}

+ (NSArray *)recursivlyCollectFileNavigableItemsFrom:(IDENavigableItem *)selectedObject {
    id items = nil;
    
    if ([selectedObject isKindOfClass:NSClassFromString(@"IDEGroupNavigableItem")]) {
        NSMutableArray *mItems = [NSMutableArray array];
        IDEGroupNavigableItem *groupNavigableItem = (IDEGroupNavigableItem *)selectedObject;
        
        for (IDENavigableItem *child in groupNavigableItem.childItems) {
            NSArray *childItems = [self recursivlyCollectFileNavigableItemsFrom:child];
            
            if (childItems.count) {
                [mItems addObjectsFromArray:childItems];
            }
        }
        
        items = mItems;
    }
    else if ([selectedObject isKindOfClass:NSClassFromString(@"IDEFileNavigableItem")]) {
        IDEFileNavigableItem *fileNavigableItem = (IDEFileNavigableItem *)selectedObject;
        NSString *uti = [[fileNavigableItem documentType] identifier];
        
        if ([[NSWorkspace sharedWorkspace] type:uti conformsToType:(NSString *)kUTTypeSourceCode]) {
            items = @[fileNavigableItem];
        }
    }
    
    return items;
}

@end
