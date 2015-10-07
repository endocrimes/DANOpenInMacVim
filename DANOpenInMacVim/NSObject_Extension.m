//
//  NSObject_Extension.m
//  DANOpenInMacVim
//
//  Created by Daniel Tomlinson on 07/10/2015.
//  Copyright © 2015 Rocket Apps. All rights reserved.
//


#import "NSObject_Extension.h"
#import "DANOpenInMacVim.h"

@implementation NSObject (Xcode_Plugin_Template_Extension)

+ (void)pluginDidLoad:(NSBundle *)plugin
{
    static dispatch_once_t onceToken;
    NSString *currentApplicationName = [[NSBundle mainBundle] infoDictionary][@"CFBundleName"];
    if ([currentApplicationName isEqual:@"Xcode"]) {
        dispatch_once(&onceToken, ^{
            sharedPlugin = [[DANOpenInMacVim alloc] initWithBundle:plugin];
        });
    }
}
@end
