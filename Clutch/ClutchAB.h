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
#import <Clutch/ClutchStats.h>
#import <Clutch/ClutchAPIClient.h>

@interface ClutchAB : NSObject {
    NSString *_appKey;
    NSString *_rpcURL;
    NSString *_fakeGUID;
}

@property (nonatomic, retain) NSString *fakeGUID;

+ (ClutchAB *)setupWithKey:(NSString *)appKey rpcURL:(NSString *)rpcURL;

+ (void)testWithName:(NSString *)name
                data:(void(^)(NSDictionary *testData))dataCallbackBlock;

+ (void)testWithName:(NSString *)name
                   A:(void(^)(void))blockA
                   B:(void(^)(void))blockB;
+ (void)testWithName:(NSString *)name
                   A:(void(^)(void))blockA
                   B:(void(^)(void))blockB
                   C:(void(^)(void))blockC;
+ (void)testWithName:(NSString *)name
                   A:(void(^)(void))blockA
                   B:(void(^)(void))blockB
                   C:(void(^)(void))blockC
                   D:(void(^)(void))blockD;
+ (void)testWithName:(NSString *)name
                   A:(void(^)(void))blockA
                   B:(void(^)(void))blockB
                   C:(void(^)(void))blockC
                   D:(void(^)(void))blockD
                   E:(void(^)(void))blockE;
+ (void)testWithName:(NSString *)name
                   A:(void(^)(void))blockA
                   B:(void(^)(void))blockB
                   C:(void(^)(void))blockC
                   D:(void(^)(void))blockD
                   E:(void(^)(void))blockE
                   F:(void(^)(void))blockF;
+ (void)testWithName:(NSString *)name
                   A:(void(^)(void))blockA
                   B:(void(^)(void))blockB
                   C:(void(^)(void))blockC
                   D:(void(^)(void))blockD
                   E:(void(^)(void))blockE
                   F:(void(^)(void))blockF
                   G:(void(^)(void))blockG;
+ (void)testWithName:(NSString *)name
                   A:(void(^)(void))blockA
                   B:(void(^)(void))blockB
                   C:(void(^)(void))blockC
                   D:(void(^)(void))blockD
                   E:(void(^)(void))blockE
                   F:(void(^)(void))blockF
                   G:(void(^)(void))blockG
                   H:(void(^)(void))blockH;
+ (void)testWithName:(NSString *)name
                   A:(void(^)(void))blockA
                   B:(void(^)(void))blockB
                   C:(void(^)(void))blockC
                   D:(void(^)(void))blockD
                   E:(void(^)(void))blockE
                   F:(void(^)(void))blockF
                   G:(void(^)(void))blockG
                   H:(void(^)(void))blockH
                   I:(void(^)(void))blockI;
+ (void)testWithName:(NSString *)name
                   A:(void(^)(void))blockA
                   B:(void(^)(void))blockB
                   C:(void(^)(void))blockC
                   D:(void(^)(void))blockD
                   E:(void(^)(void))blockE
                   F:(void(^)(void))blockF
                   G:(void(^)(void))blockG
                   H:(void(^)(void))blockH
                   I:(void(^)(void))blockI
                   J:(void(^)(void))blockJ;

+ (void)goalReached:(NSString *)name;

+ (UIColor *)colorFromHex:(NSString *)hex;

- (void)setupFakeGUID;
- (void)setAppKey:(NSString *)appKey;
- (void)setRpcURL:(NSString *)rpcURL;

@end
