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
#import <Clutch/ClutchConf.h>
#import <Clutch/ClutchAFNetworking.h>
#import <Clutch/ClutchUtils.h>

extern NSString * const kClutchAPIVersion;

@interface ClutchAPIClient : ClutchAFHTTPClient {
    NSString *_appKey;
}

+ (ClutchAPIClient *)sharedClientForKey:(NSString *)appKey rpcURL:(NSString *)rpcURL;
- (void)downloadFile:(NSString *)fileName
             version:(NSString *)version
             success:(void(^)(NSData *))successBlock_
             failure:(void(^)(NSData *, NSError *))failureBlock_;
- (void)callMethod:(NSString *)methodName
        withParams:(NSDictionary *)params
           success:(void(^)(id))successBlock_ 
           failure:(void(^)(NSData *, NSError *))failureBlock_;

@end
