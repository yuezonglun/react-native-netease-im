//
//  SubscribeViewController.h
//  RNNeteaseIm
//
//  Created by yrtec on 2019/8/17.
//  Copyright © 2019 Dowin. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

#define NTESSubscribeExpiry 60 * 60 * 24 * 1 // 订阅有效期为 1 天

@interface RNNeteaseImSubscribeManager : RCTEventEmitter <RCTBridgeModule>
- (void)performSubscribeUsers:(NSArray *)userIds completion:(void(^)(NSArray *failedUsers))handler;
- (NIMSubscribeRequest *)generateRequest;
@end
