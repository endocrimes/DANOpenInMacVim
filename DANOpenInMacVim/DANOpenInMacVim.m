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
        });
    }
    
    return self;
}

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

- (void)openInMacVim:(id)sender {
    NSURL *currentFileURL = [self currentProjectURL];
    if (currentFileURL) {
        [[NSWorkspace sharedWorkspace] openURLs:@[currentFileURL]
                        withAppBundleIdentifier:@"org.vim.MacVim"
                                        options:0
                 additionalEventParamDescriptor:nil
                              launchIdentifiers:nil];
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
