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

#import <Clutch/ClutchAPIClient.h>
#import "ClutchJSONKit.h"

NSString * const kClutchAPIVersion = @"8";

@implementation ClutchAPIClient

+ (ClutchAPIClient *)sharedClientForKey:(NSString *)appKey rpcURL:(NSString *)rpcURL {
    static ClutchAPIClient *_sharedClient = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _sharedClient = [[self alloc] initWithBaseURL:[NSURL URLWithString:rpcURL]];
        
        // Set some default headers
        [_sharedClient setDefaultHeader:@"X-UDID" value:[ClutchUtils getGUID]];
        [_sharedClient setDefaultHeader:@"X-API-Version" value:kClutchAPIVersion];
        [_sharedClient setDefaultHeader:@"X-App-Key" value:appKey];
        [_sharedClient setDefaultHeader:@"X-Bundle-Version" value:[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]];
    });
    return _sharedClient;
}

- (void)downloadFile:(NSString *)fileName
             version:(NSString *)version
             success:(void(^)(NSData *))successBlock_
             failure:(void(^)(NSData *, NSError *))failureBlock_ {
    static int callId = 0;
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            fileName, @"filename",
                            nil];
    NSDictionary *payload = [NSDictionary dictionaryWithObjectsAndKeys:
                             params, @"params",
                             @"get_file", @"method",
                             [NSNumber numberWithInt:++callId], @"id",
                             nil];
    NSMutableURLRequest *request = [self requestWithMethod:@"POST" path:@"/rpc/" parameters:nil];
    [request setValue:version forHTTPHeaderField:@"X-App-Version"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:[ClutchJSONEncoder jsonData:payload]];
    
    ClutchAFHTTPRequestOperation *operation = [[[ClutchAFHTTPRequestOperation alloc] initWithRequest:request] autorelease];
    [operation setCompletionBlockWithSuccess:^(ClutchAFHTTPRequestOperation *operation , id responseObject) {
        successBlock_((NSData *)responseObject);
    } failure:^(ClutchAFHTTPRequestOperation *operation , NSError *error) {
        failureBlock_(operation.responseData, error);
    }];
    NSOperationQueue *queue = [[[NSOperationQueue alloc] init] autorelease];
    [queue addOperation:operation];
}

- (void)callMethod:(NSString *)methodName
        withParams:(NSDictionary *)params
           success:(void(^)(id))successBlock_ 
           failure:(void(^)(NSData *, NSError *))failureBlock_ {
    static int callId = 0;
    if(params == nil) {
        params = [NSDictionary dictionary];
    }
    NSDictionary *payload = [NSDictionary dictionaryWithObjectsAndKeys:
                                params, @"params",
                                methodName, @"method",
                                [NSNumber numberWithInt:++callId], @"id",
                             nil];
    NSMutableURLRequest *request = [self requestWithMethod:@"POST" path:@"/rpc/" parameters:nil];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"%i", [ClutchConf version]] forHTTPHeaderField:@"X-App-Version"];
    [request setHTTPBody:[ClutchJSONEncoder jsonData:payload]];
    ClutchAFHTTPRequestOperation *operation = [[[ClutchAFHTTPRequestOperation alloc] initWithRequest:request] autorelease];
    [operation setCompletionBlockWithSuccess:^(ClutchAFHTTPRequestOperation *operation , id responseObject) {
        NSDictionary *resp = [[ClutchJSONDecoder decoder] objectWithData:operation.responseData];
        NSDictionary *error = [resp objectForKey:@"error"];
        id result = [resp objectForKey:@"result"];
        if(error == nil || [[NSNull null] isEqual:error]) {
            successBlock_(result);
        } else {
            NSError *errorObj = [NSError errorWithDomain:@"ClutchAPIClient"
                                                    code:*(NSInteger *)[error objectForKey:@"code"] 
                                                userInfo:error];
            failureBlock_((NSData *)responseObject, errorObj);
        }
    } failure:^(ClutchAFHTTPRequestOperation *operation , NSError *error) {
        failureBlock_(operation.responseData, error);
    }];
    NSOperationQueue *queue = [[[NSOperationQueue alloc] init] autorelease];
    [queue addOperation:operation];
}

@end
