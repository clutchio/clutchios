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

#import <Clutch/ClutchSync.h>
#import "ClutchJSONKit.h"
#import "ClutchAFNetworking.h"
#import "UIDevice+IdentifierAddition.h"

@implementation ClutchSync

+ (ClutchSync *)sharedClientForKey:(NSString *)appKey
                         tunnelURL:(NSString *)tunnelURL
                            rpcURL:(NSString *)rpcURL {
    static ClutchSync *_sharedClient = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _sharedClient = [[self alloc] init];
        [_sharedClient setAppKey:appKey];
        [_sharedClient setTunnelURL:tunnelURL];
        [_sharedClient setRpcURL:rpcURL];
    });
    return _sharedClient;
}

- (NSString *)getCacheDir {
    NSString *bundleVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    return [NSString stringWithFormat:@"%@/Library/Caches/__clutchcache/%@/", NSHomeDirectory(), bundleVersion];
}

- (void)watchForChanges {
    NSString *maybeSlash = nil;
    if([_tunnelURL hasSuffix:@"/"]) {
        maybeSlash = @"";
    } else {
        maybeSlash = @"/";
    }
    NSString *url = [NSString stringWithFormat:@"%@%@phonepoll/%@/%@/%@",
                     _tunnelURL,
                     maybeSlash,
                     [[UIDevice currentDevice] uniqueGlobalDeviceIdentifier],
                     _appKey,
                     _cursor == nil ? @"" : [NSString stringWithFormat:@"?cursor=%@", _cursor]
                    ];
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
    ClutchAFHTTPRequestOperation *operation = [[ClutchAFHTTPRequestOperation alloc] initWithRequest:request];
    operation.completionBlock = ^{
        if ([operation hasAcceptableStatusCode]) {
            if(!_shouldWatchForChanges) {
                return;
            }
            
            NSDictionary *resp = [[ClutchJSONDecoder decoder] objectWithData:operation.responseData];
            
            NSArray *messages = [resp objectForKey:@"messages"];
            if([messages count] > 0) {
                [[NSNotificationCenter defaultCenter] postNotificationName:@"ClutchReloadView" object:nil];
                _cursor = [[resp objectForKey:@"id"] retain];
            }
            [self watchForChanges];
        } else {
            [self performSelector:@selector(watchForChanges) withObject:nil afterDelay:1.0];
        }
    };
    NSOperationQueue *queue = [[[NSOperationQueue alloc] init] autorelease];
    [queue addOperation:operation];
}

- (void)sync {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ClutchSyncStarted" object:self];
    if(_pendingReload) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"ClutchReloadView" object:nil];
        _pendingReload = FALSE;
    }
    ClutchAPIClient *client = [ClutchAPIClient sharedClientForKey:_appKey rpcURL:_rpcURL];
    [client callMethod:@"sync" withParams:nil success:^(id object) {
        NSDictionary *resp = (NSDictionary *)object;
        
        NSString *cacheDir = [self getCacheDir];
        
        // First get a file manager and set up a temporary working directory
        NSFileManager *filemgr = [NSFileManager defaultManager];
        NSString *tmpDir = [NSString stringWithFormat:@"%@/Library/Caches/__clutchtmp/%i/", NSHomeDirectory(), arc4random()];
        
        if([filemgr fileExistsAtPath:cacheDir]) {
            // If the cache dir already exists, then we need to copy its contents to the temporary directory
            NSString *tmpParentDir = [tmpDir stringByDeletingLastPathComponent];
            [filemgr createDirectoryAtPath:tmpParentDir withIntermediateDirectories:YES attributes:nil error:nil];
            [filemgr copyItemAtPath:cacheDir toPath:tmpDir error:nil];
        } else {
            // Otherwise, we just create a new empty temporary directory
            [filemgr createDirectoryAtPath:tmpDir withIntermediateDirectories:YES attributes:nil error:nil];
        }
        
        // Extract the conf from the sync object and munge the timestamps (if any)
        NSMutableDictionary *conf = [[[resp objectForKey:@"conf"] mutableCopy] autorelease];
        NSArray *timestamps = [conf objectForKey:@"_timestamps"];
        if(timestamps) {
            for(NSString *timestamp in timestamps) {
                NSDate *date = [NSDate dateWithTimeIntervalSince1970:[[conf objectForKey:timestamp] floatValue]];
                [conf setObject:date forKey:timestamp];
            }
        }
        [conf removeObjectForKey:@"_timestamps"];
        
        NSString *version = [NSString stringWithFormat:@"%@", [conf objectForKey:@"_version"]];
        
        __block BOOL newFilesDownloaded = FALSE;
        
        // If there has been a change in configs, then we should deal with it
        if(![[ClutchConf conf] isEqualToDictionary:conf]) {
            newFilesDownloaded = TRUE;
            
            // Make sure we NEVER save out a version with _dev = TRUE
            NSMutableDictionary *confToWrite = [[conf mutableCopy] autorelease];
            [confToWrite setValue:[NSNumber numberWithBool:FALSE] forKey:@"_dev"];
            
            NSString *errorString1;
            NSData *plistData = [NSPropertyListSerialization dataFromPropertyList:confToWrite
                                                                           format:NSPropertyListXMLFormat_v1_0
                                                         errorDescription:&errorString1];
            
            NSString *confPlist = [NSString stringWithFormat:@"%@__conf.plist", tmpDir];
            if(plistData) {
                [plistData writeToFile:confPlist atomically:YES];
            } else {
                NSLog(@"(Clutch) Error writing out conf plist: %@\n", errorString1);
            }
            if(errorString1) {
                [errorString1 release];
            }
        }
        
        __block int errorDownloadingFile = 0;
        
        // This will run once all of the files have been downloaded or if there were no new files
        void (^complete) (void) = ^{
            if(errorDownloadingFile > 0) {
                NSLog(@"(Clutch) Since there was an error downloading file from server, the app will not sync right now.\n");
                if(newFilesDownloaded) {
                    // Remove the temporary directory if it exists
                    [filemgr removeItemAtPath:cacheDir error:nil];
                }
                NSDictionary *syncFinishedObj = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:FALSE], @"newFilesDownloaded", nil];
                [[NSNotificationCenter defaultCenter] postNotificationName:@"ClutchSyncFinished" object:self userInfo:syncFinishedObj];
                return;
            }
            
            if(newFilesDownloaded) {
                // Create the parent directory if it doesn't exist
                NSString *parentDir = [cacheDir stringByDeletingLastPathComponent];
                [filemgr createDirectoryAtPath:parentDir withIntermediateDirectories:YES attributes:nil error:nil];
                // Remove the directory if it *does* exist
                [filemgr removeItemAtPath:cacheDir error:nil];
                // Now move our temporary directory over to where it should be
                [filemgr moveItemAtPath:tmpDir toPath:cacheDir error:nil];
            }
            
            [ClutchConf setConf:conf];
            
            NSDictionary *syncFinishedObj = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:newFilesDownloaded], @"newFilesDownloaded", nil];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"ClutchSyncFinished" object:self userInfo:syncFinishedObj];
            NSLog(@"(Clutch) Sync complete.\n");
            
            // If we're in dev mode, or have seen any new files, make sure we reload the next time we are foregrounded
            if([[conf objectForKey:@"_dev"] boolValue] || newFilesDownloaded) {
                _pendingReload = TRUE;
            }

            // If we're in dev mode, reload right now
            if([[conf objectForKey:@"_dev"] boolValue]) {
                [[NSNotificationCenter defaultCenter] postNotificationName:@"ClutchReloadView" object:nil];
                // If there's no toolbar, start the auto-reloader
                if(![[conf objectForKey:@"_toolbar"] boolValue]) {
                    _shouldWatchForChanges = TRUE;
                    [self watchForChanges];
                }
            }
        };

        NSString *cachedFiles = [NSString stringWithFormat:@"%@__files.plist", cacheDir];
        NSDictionary *cached;
        if([filemgr fileExistsAtPath:cachedFiles]) {
            [filemgr contentsAtPath:cachedFiles];
            cached = [NSDictionary dictionaryWithContentsOfFile:cachedFiles];
        } else {
            cached = [NSDictionary dictionary];
        }
        
        NSDictionary *files = [resp objectForKey:@"files"];
        if([cached isEqualToDictionary:files]) {
            complete();
            return;
        }
        
        // Now we write the newly-fetched file list into our working directory
        NSString *errorString2;
        NSData *plistData = [NSPropertyListSerialization dataFromPropertyList:files
                                                                       format:NSPropertyListXMLFormat_v1_0
                                                             errorDescription:&errorString2];
        if(plistData) {
            [plistData writeToFile:[NSString stringWithFormat:@"%@__files.plist", tmpDir] atomically:YES];
        } else {
            NSLog(@"(Clutch) Error writing out file cache plist: %@\n", errorString2);
        }
        if(errorString2) {
            [errorString2 release];
        }
        
        int numFiles = [files count];
        __block int currentFile = 0;
        
        [files enumerateKeysAndObjectsUsingBlock:^(NSString *fileName, NSString *hash, BOOL *stop) {
            NSString *prevHash = [cached objectForKey:fileName];
            
            // If they equal, then just continue
            if([prevHash isEqualToString:hash]) {
                if(++currentFile == numFiles) {
                    complete();
                }
                return;
            }
            
            // Looks like we've seen a new file, so we should reload when this is all done
            newFilesDownloaded = TRUE;
            
            // Otherwise we need to download the new file
            NSString *fullFileName = [tmpDir stringByAppendingPathComponent:fileName];
            [client downloadFile:fileName version:version success:^(NSData *data) {
                NSLog(@"(Clutch) Downloaded new file: %@\n", fileName);
                NSString *dir = [fullFileName stringByDeletingLastPathComponent];
                [filemgr createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
                [filemgr createFileAtPath:fullFileName contents:data attributes:nil];
                if(++currentFile == numFiles) {
                    complete();
                }
            } failure:^(NSData *data, NSError *error) {
                NSString *st = [[[NSString alloc] initWithData:data
                                                      encoding:NSUTF8StringEncoding] autorelease];
                NSLog(@"(Clutch) Error downloading file from server: %@\n", st);
                errorDownloadingFile++;
                if(++currentFile == numFiles) {
                    complete();
                }
            }];
            
        }];
    } failure:^(NSData *data, NSError *error) {
        NSLog(@"Failed to connect to the Clutch server.  Could not sync. %@\n", error);
        // Since we couldn't connect to the clutch server, syncing is finished, so we can signal that.
        NSDictionary *syncFinishedObj = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:FALSE], @"newFilesDownloaded", nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"ClutchSyncFinished" object:self userInfo:syncFinishedObj];
    }];
    [self background];
}

- (void)background {
    ClutchAPIClient *apiClient = [ClutchAPIClient sharedClientForKey:_appKey rpcURL:_rpcURL];
    ClutchStats *statsClient = [ClutchStats sharedClient];
    NSArray *logs = [statsClient getLogs];
    if([logs count] == 0) {
        return;
    }
    NSTimeInterval lastTimestamp = [[[logs lastObject] objectForKey:@"ts"] doubleValue];
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:logs, @"logs", nil];
    [apiClient callMethod:@"stats" withParams:params success:^(id object) {
        if([[(NSDictionary *)object objectForKey:@"status"] isEqualToString:@"ok"]) {
            [statsClient deleteLogs:lastTimestamp];
        } else {
            //NSLog(@"Failed to send the Clutch stats logs to the server.\n");
        }
    } failure:^(NSData *data, NSError *error) {
        //NSLog(@"Failed to connect to the Clutch server. %@\n", error);
    }];
}

- (void)foreground {
    [self sync];
}

#pragma mark - Setters

- (void)setAppKey:(NSString *)appKey {
    [appKey retain];
    [_appKey release];
    _appKey = appKey;
}

- (void)setTunnelURL:(NSString *)tunnelURL {
    [tunnelURL retain];
    [_tunnelURL release];
    _tunnelURL = tunnelURL;
}

- (void)setRpcURL:(NSString *)rpcURL {
    [rpcURL retain];
    [_rpcURL release];
    _rpcURL = rpcURL;
}

@end
