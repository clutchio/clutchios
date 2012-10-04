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

#import <Clutch/ClutchConf.h>

@implementation ClutchConf

static NSDictionary *_confData = nil;

+ (void)setConf:(NSDictionary *)conf {
    if([conf isEqualToDictionary:_confData]) {
        return;
    }
    [conf retain];
    [_confData release];
    _confData = conf;
}

+ (NSString *)_getClutchSubdir {
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSDirectoryEnumerator *dirEnum = [fileManager enumeratorAtPath:bundlePath];
    
    NSString *file;
    NSString *confPlist;
    while(file = [dirEnum nextObject]) {
        if([[file lastPathComponent] isEqualToString:@"clutch.plist"]) {
            confPlist = file;
            break;
        }
    }
    
    if(!confPlist) {
        return nil;
    }
    NSArray *dirParts = [confPlist componentsSeparatedByString:@"/"];
    if([dirParts count] <= 1) {
        return nil;
    }
    NSString *lastPath = [dirParts objectAtIndex:[dirParts count] - 2];
    return [[bundlePath stringByAppendingPathComponent:lastPath] retain];
}

+ (NSString *)getClutchSubdir {
    static NSString *_clutchSubdir = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _clutchSubdir = [ClutchConf _getClutchSubdir];
    });
    return _clutchSubdir;
}

+ (NSDictionary *)conf {
    // If the config data hasn't been set yet, then we need to try a backup plan
    if(_confData == nil) {
        NSFileManager *filemgr = [NSFileManager defaultManager];
        // First we look for a saved plist file that ClutchSync creates
        NSString *bundleVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
        NSString *confPlist = [NSString stringWithFormat:@"%@/Library/Caches/__clutchcache/%@/__conf.plist", NSHomeDirectory(), bundleVersion];
        if([filemgr fileExistsAtPath:confPlist]) {
            _confData = [[NSDictionary dictionaryWithContentsOfFile:confPlist] retain];
        } else {
            NSString *clutchSubdir = [ClutchConf getClutchSubdir];
            if(clutchSubdir == nil) {
                _confData = [[NSDictionary dictionary] retain];
                return _confData;
            }
            confPlist = [[NSBundle mainBundle] pathForResource:@"clutch" ofType:@"plist" inDirectory:clutchSubdir];
            // Look for an SHConf.plist in the app's bundle
            if(confPlist == nil) {
                // We couldn't find it, just initialize an empty dictionary
                _confData = [[NSDictionary dictionary] retain];
            } else {
                // Hooray, we found a bundled SHConf.plist, so use that
                _confData = [[NSDictionary dictionaryWithContentsOfFile:confPlist] retain];
            }
        }
    }
    return _confData;
}

+ (NSInteger)version {
    NSNumber *ver = [[ClutchConf conf] objectForKey:@"_version"];
    if(ver == nil) {
        return -1;
    }
    return [ver intValue];
}

@end
