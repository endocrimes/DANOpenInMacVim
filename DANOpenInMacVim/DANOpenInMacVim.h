//
//  DANOpenInMacVim.h
//  DANOpenInMacVim
//
//  Created by  Danielle Lancashireon 07/10/2015.
//  Copyright © 2015 Rocket Apps. All rights reserved.
//

#import <AppKit/AppKit.h>

@class DANOpenInMacVim;

static DANOpenInMacVim *sharedPlugin;

@interface DANOpenInMacVim : NSObject

+ (instancetype)sharedPlugin;
- (id)initWithBundle:(NSBundle *)plugin;

@property (nonatomic, strong, readonly) NSBundle* bundle;
@end