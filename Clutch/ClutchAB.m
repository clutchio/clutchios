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

#import "ClutchAB.h"

#define ARC4RANDOM_MAX 0x100000000

@implementation ClutchAB

+ (ClutchAB *)setupWithKey:(NSString *)appKey rpcURL:(NSString *)rpcURL {
    static ClutchAB *_sharedClient = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _sharedClient = [[self alloc] init];
        [_sharedClient setAppKey:appKey];
        [_sharedClient setRpcURL:rpcURL];
        [_sharedClient setupFakeGUID];
        
        [[NSNotificationCenter defaultCenter] addObserver:_sharedClient
                                                 selector:@selector(applicationDidBecomeActive:)
                                                     name:UIApplicationDidBecomeActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:_sharedClient
                                                 selector:@selector(applicationDidEnterBackground:)
                                                     name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:_sharedClient
                                                 selector:@selector(applicationDidFinishLaunching:)
                                                     name:UIApplicationDidFinishLaunchingNotification object:nil];
    });
    return _sharedClient;
}

- (void)_sendABLogs {
    ClutchAPIClient *apiClient = [ClutchAPIClient sharedClientForKey:_appKey rpcURL:_rpcURL];
    ClutchStats *statsClient = [ClutchStats sharedClient];
    NSArray *logs = [statsClient getABLogs];
    if([logs count] == 0) {
        return;
    }
    NSTimeInterval lastTimestamp = [[[logs lastObject] objectForKey:@"ts"] doubleValue];
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:logs, @"logs", _fakeGUID, @"guid", nil];
    [apiClient callMethod:@"send_ab_logs" withParams:params success:^(id object) {
        if([[(NSDictionary *)object objectForKey:@"status"] isEqualToString:@"ok"]) {
            [statsClient deleteABLogs:lastTimestamp];
        } else {
            NSLog(@"Failed to actually download the Clutch AB metadata from the server.\n");
        }
    } failure:^(NSData *data, NSError *error) {
        NSLog(@"Failed to connect to the Clutch server to get AB metadata. %@\n", error);
    }];
}

- (void)_downloadABMetadata {
    ClutchAPIClient *apiClient = [ClutchAPIClient sharedClientForKey:_appKey rpcURL:_rpcURL];
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:_fakeGUID, @"guid", nil];
    [apiClient callMethod:@"get_ab_metadata" withParams:params success:^(id object) {
        NSDictionary *metadata = [(NSDictionary *)object objectForKey:@"metadata"];
        NSString *errorString1;
        NSData *plistData = [NSPropertyListSerialization dataFromPropertyList:metadata
                                                                       format:NSPropertyListXMLFormat_v1_0
                                                             errorDescription:&errorString1];
        
        NSString *abPlist = [NSString stringWithFormat:@"%@/Library/Caches/__clutchab.plist", NSHomeDirectory()];
        if(plistData) {
            [plistData writeToFile:abPlist atomically:YES];
        } else {
            NSLog(@"(Clutch) Error writing out AB plist: %@\n", errorString1);
        }
        if(errorString1) {
            [errorString1 release];
        }
    } failure:^(NSData *data, NSError *error) {
        NSLog(@"Failed to connect to the Clutch server to send AB logs. %@\n", error);
    }];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    if(_appKey == nil) {
        return;
    }
    [self _sendABLogs];
    [self _downloadABMetadata];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    if(_appKey == nil) {
        return;
    }
    [self _sendABLogs];
}

- (void)applicationDidFinishLaunching:(UIApplication *)application {
    if(_appKey == nil) {
        return;
    }
    [self _sendABLogs];
    [self _downloadABMetadata];
}

+ (NSDictionary *)getLatestMetadata {
    // TODO: Cache
    NSString *abPlist = [NSString stringWithFormat:@"%@/Library/Caches/__clutchab.plist", NSHomeDirectory()];
    if([[NSFileManager defaultManager] fileExistsAtPath:abPlist]) {
        return [NSDictionary dictionaryWithContentsOfFile:abPlist];
    } else {
        return [NSDictionary dictionary];
    }
}

+ (int)weightedChoice:(NSArray *)weights {
    double total = 0;
    int winner = 0;
    for(int i = 0; i < [weights count]; ++i) {
        NSNumber *weight = [weights objectAtIndex:i];
        total += [weight doubleValue];
        double rnd = (double)arc4random() / ARC4RANDOM_MAX;
        if(rnd * total < [weight doubleValue]) {
            winner = i;
        }
    }
    double shouldTestRnd = (double)arc4random() / ARC4RANDOM_MAX;
    if(shouldTestRnd <= total) {
        return winner;
    }
    return -1;
}

+ (int)cachedChoiceForTestNamed:(NSString *)name weights:(NSArray *)weights {
    ClutchStats *statsClient = [ClutchStats sharedClient];
    int resp = [statsClient getCachedChoice:name];
    if(resp == -1) {
        resp = [ClutchAB weightedChoice:weights];
        [statsClient setCachedChoice:name choice:resp];
    }
    return resp;
}

+ (void)testWithName:(NSString *)name
                data:(void(^)(NSDictionary *testData))dataCallbackBlock {
    NSDictionary *metaMeta = [ClutchAB getLatestMetadata];
    if([metaMeta count] == 0) {
        return;
    }
    NSDictionary *meta = [metaMeta objectForKey:name];
    if(meta == nil) {
        [[ClutchStats sharedClient] testFailure:name type:@"no-meta-name"];
        [[ClutchStats sharedClient] setNumChoices:0 forTest:name hasData:true];
        return;
    }
    NSArray *weights = [meta objectForKey:@"weights"];
    NSArray *allData = [meta objectForKey:@"data"];
    if(allData == nil || weights == nil) {
        [[ClutchStats sharedClient] testFailure:name type:@"no-data"];
        return;
    }
    if([weights count] == 0) {
        return;
    }
    int choice = [ClutchAB cachedChoiceForTestNamed:name weights:weights];
    [[ClutchStats sharedClient] testChosen:name choice:choice numChoices:[weights count]];
    if(choice == -1) {
        return;
    }
    NSDictionary *data = [allData objectAtIndex:choice];
    dataCallbackBlock(data);
}

+ (void)testWithName:(NSString *)name
              blocks:(NSArray *)blocks {
    NSDictionary *metaMeta = [ClutchAB getLatestMetadata];
    if([metaMeta count] == 0) {
        return;
    }
    NSDictionary *meta = [metaMeta objectForKey:name];
    NSArray *weights = [meta objectForKey:@"weights"];
    if(meta == nil || weights == nil) {
        if(meta == nil) {
            [[ClutchStats sharedClient] testFailure:name type:@"no-meta-name"];
        } else if(weights == nil) {
            [[ClutchStats sharedClient] testFailure:name type:@"no-weights"];
        }
        [[ClutchStats sharedClient] setNumChoices:[blocks count] forTest:name hasData:false];
        return;
    }
    int choice = [ClutchAB cachedChoiceForTestNamed:name weights:weights];
    [[ClutchStats sharedClient] testChosen:name choice:choice  numChoices:[blocks count]];
    if(choice == -1) {
        return;
    }
    void(^complete)(void) = [blocks objectAtIndex:choice];
    complete();
}

+ (void)testWithName:(NSString *)name
                   A:(void(^)(void))blockA
                   B:(void(^)(void))blockB {
    NSArray *blocks = [NSArray arrayWithObjects:
                       [[blockA copy] autorelease],
                       [[blockB copy] autorelease],
                       nil];
    [ClutchAB testWithName:name blocks:blocks];
}

+ (void)testWithName:(NSString *)name
                   A:(void(^)(void))blockA
                   B:(void(^)(void))blockB
                   C:(void(^)(void))blockC {
    NSArray *blocks = [NSArray arrayWithObjects:
                       [[blockA copy] autorelease],
                       [[blockB copy] autorelease],
                       [[blockC copy] autorelease],
                       nil];
    [ClutchAB testWithName:name blocks:blocks];
}

+ (void)testWithName:(NSString *)name
                   A:(void(^)(void))blockA
                   B:(void(^)(void))blockB
                   C:(void(^)(void))blockC
                   D:(void(^)(void))blockD {
    NSArray *blocks = [NSArray arrayWithObjects:
                       [[blockA copy] autorelease],
                       [[blockB copy] autorelease],
                       [[blockC copy] autorelease],
                       [[blockD copy] autorelease],
                       nil];
    [ClutchAB testWithName:name blocks:blocks];
}

+ (void)testWithName:(NSString *)name
                   A:(void(^)(void))blockA
                   B:(void(^)(void))blockB
                   C:(void(^)(void))blockC
                   D:(void(^)(void))blockD
                   E:(void(^)(void))blockE {
    NSArray *blocks = [NSArray arrayWithObjects:
                       [[blockA copy] autorelease],
                       [[blockB copy] autorelease],
                       [[blockC copy] autorelease],
                       [[blockD copy] autorelease],
                       [[blockE copy] autorelease],
                       nil];
    [ClutchAB testWithName:name blocks:blocks];
}

+ (void)testWithName:(NSString *)name
                   A:(void(^)(void))blockA
                   B:(void(^)(void))blockB
                   C:(void(^)(void))blockC
                   D:(void(^)(void))blockD
                   E:(void(^)(void))blockE
                   F:(void(^)(void))blockF {
    NSArray *blocks = [NSArray arrayWithObjects:
                       [[blockA copy] autorelease],
                       [[blockB copy] autorelease],
                       [[blockC copy] autorelease],
                       [[blockD copy] autorelease],
                       [[blockE copy] autorelease],
                       [[blockF copy] autorelease],
                       nil];
    [ClutchAB testWithName:name blocks:blocks];
}

+ (void)testWithName:(NSString *)name
                   A:(void(^)(void))blockA
                   B:(void(^)(void))blockB
                   C:(void(^)(void))blockC
                   D:(void(^)(void))blockD
                   E:(void(^)(void))blockE
                   F:(void(^)(void))blockF
                   G:(void(^)(void))blockG {
    NSArray *blocks = [NSArray arrayWithObjects:
                       [[blockA copy] autorelease],
                       [[blockB copy] autorelease],
                       [[blockC copy] autorelease],
                       [[blockD copy] autorelease],
                       [[blockE copy] autorelease],
                       [[blockF copy] autorelease],
                       [[blockG copy] autorelease],
                       nil];
    [ClutchAB testWithName:name blocks:blocks];
}

+ (void)testWithName:(NSString *)name
                   A:(void(^)(void))blockA
                   B:(void(^)(void))blockB
                   C:(void(^)(void))blockC
                   D:(void(^)(void))blockD
                   E:(void(^)(void))blockE
                   F:(void(^)(void))blockF
                   G:(void(^)(void))blockG
                   H:(void(^)(void))blockH {
    NSArray *blocks = [NSArray arrayWithObjects:
                       [[blockA copy] autorelease],
                       [[blockB copy] autorelease],
                       [[blockC copy] autorelease],
                       [[blockD copy] autorelease],
                       [[blockE copy] autorelease],
                       [[blockF copy] autorelease],
                       [[blockG copy] autorelease],
                       [[blockH copy] autorelease],
                       nil];
    [ClutchAB testWithName:name blocks:blocks];
}

+ (void)testWithName:(NSString *)name
                   A:(void(^)(void))blockA
                   B:(void(^)(void))blockB
                   C:(void(^)(void))blockC
                   D:(void(^)(void))blockD
                   E:(void(^)(void))blockE
                   F:(void(^)(void))blockF
                   G:(void(^)(void))blockG
                   H:(void(^)(void))blockH
                   I:(void(^)(void))blockI {
    NSArray *blocks = [NSArray arrayWithObjects:
                       [[blockA copy] autorelease],
                       [[blockB copy] autorelease],
                       [[blockC copy] autorelease],
                       [[blockD copy] autorelease],
                       [[blockE copy] autorelease],
                       [[blockF copy] autorelease],
                       [[blockG copy] autorelease],
                       [[blockH copy] autorelease],
                       [[blockI copy] autorelease],
                       nil];
    [ClutchAB testWithName:name blocks:blocks];
}

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
                   J:(void(^)(void))blockJ {
    NSArray *blocks = [NSArray arrayWithObjects:
                       [[blockA copy] autorelease],
                       [[blockB copy] autorelease],
                       [[blockC copy] autorelease],
                       [[blockD copy] autorelease],
                       [[blockE copy] autorelease],
                       [[blockF copy] autorelease],
                       [[blockG copy] autorelease],
                       [[blockH copy] autorelease],
                       [[blockI copy] autorelease],
                       [[blockJ copy] autorelease],
                       nil];
    [ClutchAB testWithName:name blocks:blocks];
}

+ (void)goalReached:(NSString *)name {
    [[ClutchStats sharedClient] goalReached:name];
}

+ (UIColor *)colorFromHex:(NSString *)hex {
    NSString *correctedHex = nil;
    if([hex hasPrefix:@"#"]) {
        correctedHex = [hex substringFromIndex:1];
    } else {
        correctedHex = hex;
    }
    
    if([correctedHex length] == 3) {
        correctedHex = [NSString stringWithFormat:@"%C%C%C%C%C%C",
                        [correctedHex characterAtIndex:0],
                        [correctedHex characterAtIndex:0],
                        [correctedHex characterAtIndex:1],
                        [correctedHex characterAtIndex:1],
                        [correctedHex characterAtIndex:2],
                        [correctedHex characterAtIndex:2]
                        ];
    }
    
    unsigned int hexVal;
    NSScanner *scanner = [NSScanner scannerWithString:correctedHex];
    [scanner scanHexInt:&hexVal];
    
    if([correctedHex length] == 6) {
        return [UIColor colorWithRed:((hexVal & 0xFF0000) >> 16)/255.0
                               green:((hexVal & 0xFF00) >> 8)/255.0
                                blue:(hexVal & 0xFF)/255.0
                               alpha:1];
    } else if([correctedHex length] == 8) {
        return [UIColor colorWithRed:((hexVal & 0xFF000000) >> 24)/255.0
                               green:((hexVal & 0x00FF0000) >> 16)/255.0
                                blue:((hexVal & 0x0000FF00) >> 8)/255.0
                               alpha:(hexVal & 0x000000FF)/255.0];
    } else {
        NSLog(@"Invalid color hex string: '%@'. Using black instead.\n", hex);
        return [UIColor blackColor];
    }
}

#pragma mark - Misc

- (void)setFakeGUID:(NSString *)fakeGUID {
    [fakeGUID retain];
    [_fakeGUID release];
    _fakeGUID = fakeGUID;
}

- (void)setupFakeGUID {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [self setFakeGUID:[defaults objectForKey:@"fakeUUID"]];
    if(_fakeGUID == nil) {
        [self setFakeGUID:[ClutchUtils getUUID]];
        [defaults setValue:_fakeGUID forKey:@"fakeUUID"];
        [defaults synchronize];
    }
}


#pragma mark - Setters

- (void)setAppKey:(NSString *)appKey {
    [appKey retain];
    [_appKey release];
    _appKey = appKey;
}

- (void)setRpcURL:(NSString *)rpcURL {
    [rpcURL retain];
    [_rpcURL release];
    _rpcURL = rpcURL;
}

@end
