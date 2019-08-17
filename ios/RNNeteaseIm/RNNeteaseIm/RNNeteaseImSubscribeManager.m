//
//  SubscribeViewController.m
//  RNNeteaseIm
//
//  Created by yrtec on 2019/8/17.
//  Copyright © 2019 Dowin. All rights reserved.
//

#import "RNNeteaseImSubscribeManager.h"

@interface RNNeteaseImSubscribeManager()<NIMEventSubscribeManagerDelegate> {
}

@property (nonatomic,strong) NSMutableDictionary *events;
@property (nonatomic,strong) NSMutableSet *subscribeIds;
@property NSMutableArray * failedUsers;

@end

@implementation RNNeteaseImSubscribeManager

RCT_EXPORT_MODULE();

// 订阅用户在线状态
RCT_EXPORT_METHOD(subscribeOnlineState: (nonnull NSArray *)userIds resolve:(RCTPromiseResolveBlock) resolve
                  reject:(RCTPromiseRejectBlock)reject) {
    [self performSubscribeUsers:userIds completion:^(NSArray *faildUsers) {
        if (faildUsers.count) {
            reject(@"-1", @"订阅用户在线状态失败", nil);
        } else {
            resolve(userIds);
        }
    }];
}

- (NSArray<NSString *> *)supportedEvents
{
    return @[@"onlineStateChanged"];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.events = [[NSMutableDictionary alloc] init];
        self.subscribeIds = [[NSMutableSet alloc] init];
        self.failedUsers = [[NSMutableArray alloc] init];
        [[NIMSDK sharedSDK].subscribeManager addDelegate:self];
    }
    return self;
}

// 订阅用户状态
- (void) performSubscribeUsers:(NSArray *)userIds completion:(void (^)(NSArray *))handler {
    if (!userIds.count) {
        handler(_failedUsers);
        return;
    }
    
    [_subscribeIds addObjectsFromArray:userIds];
    
    NIMSubscribeRequest *request = [self generateRequest];
    NSInteger maxRequestCount = 100;
    NSArray *publishers;
    NSRange remove = userIds.count > maxRequestCount? NSMakeRange(0, maxRequestCount): NSMakeRange(0, userIds.count);
    publishers = [userIds subarrayWithRange:remove];
    
    request.publishers = publishers;
    
    __weak typeof(self) weakSelf = self;
    [[NIMSDK sharedSDK].subscribeManager subscribeEvent:request completion:^(NSError * _Nullable error, NSArray * _Nullable failedPublishers) {
        DDLogInfo(@"subscribe publisher:%@ error: %@  failed publishers: %@",request.publishers,error,failedPublishers);
        NSMutableArray *members = [userIds mutableCopy];
        [members removeObjectsInRange:remove];
        [_failedUsers arrayByAddingObjectsFromArray:failedPublishers];

        [weakSelf performSubscribeUsers:members completion:handler];
    }];
}

- (NIMSubscribeRequest *)generateRequest
{
    NIMSubscribeRequest *request = [[NIMSubscribeRequest alloc] init];
    request.type = NIMSubscribeSystemEventTypeOnline;
    request.expiry = NTESSubscribeExpiry;
    request.syncEnabled = YES;
    return request;
}

#pragma mark - NIMEventSubscribeManagerDelegate

- (void)onRecvSubscribeEvents:(NSArray *)events
{
    NSMutableArray *unSubscribeUsers = [[NSMutableArray alloc] init];
    for (NIMSubscribeEvent *event in events) {
        if ([self.subscribeIds containsObject:event.from])
        {
            NSInteger type = event.type;
            NSMutableDictionary *eventsDict = [self.events objectForKey:@(type)];
            if (!eventsDict) {
                eventsDict = [[NSMutableDictionary alloc] init];
                [self.events setObject:eventsDict forKey:@(type)];
            }
            NIMSubscribeEvent *oldEvent = [eventsDict objectForKey:event.from];
            if (oldEvent.timestamp > event.timestamp)
            {
                // 服务器不保证事件的顺序，如果发现是同类型的过期事件，根据自身业务情况决定是否过滤。
                DDLogInfo(@"event id %@ from %@ is out of date, ingore...",event.eventId,event.from);
            }
            else
            {
                [eventsDict setObject:event forKey:event.from];
                DDLogInfo(@"receive event id %@ from %@ time %.2f",event.eventId,event.from,event.timestamp);
                if (event.type == NIMSubscribeSystemEventTypeOnline) {
                    [self sendEventWithName:@"onlineStateChanged" body:@{@"userId": event.from, @"state": @([event value])}];
                }
            }
        }
        else
        {
            // 删掉了或者是以前订阅的没有干掉，这里反订阅一下
            [unSubscribeUsers addObject:event.from];
        }
    }
    
    // 反订阅
    if (unSubscribeUsers.count)
    {
        NIMSubscribeRequest *request = [self generateRequest];
        request.publishers = [NSArray arrayWithArray:unSubscribeUsers];
        [[NIMSDK sharedSDK].subscribeManager unSubscribeEvent:request completion:^(NSError * _Nullable error, NSArray * _Nullable failedPublishers) {
            DDLogInfo(@"unSubscribe publisher:%@ error: %@  failed publishers: %@",request.publishers,error,failedPublishers);
        }];
    }
}

@end
