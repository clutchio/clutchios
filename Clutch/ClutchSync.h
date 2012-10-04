//
// Copyright 2012 Twitter
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import <Foundation/Foundation.h>
#import <Clutch/ClutchAPIClient.h>
#import <Clutch/ClutchConf.h>
#import <Clutch/ClutchStats.h>

@interface ClutchSync : NSObject {
    NSString *_appKey;
    NSString *_tunnelURL;
    NSString *_rpcURL;
    BOOL _shouldWatchForChanges;
    BOOL _pendingReload;
    NSString *_cursor;
}

+ (ClutchSync *)sharedClientForKey:(NSString *)appKey
                         tunnelURL:(NSString *)tunnelURL
                            rpcURL:(NSString *)rpcURL;
- (void)sync;
- (void)background;
- (void)foreground;

- (void)setAppKey:(NSString *)appKey;
- (void)setTunnelURL:(NSString *)tunnelURL;
- (void)setRpcURL:(NSString *)rpcURL;

@end
