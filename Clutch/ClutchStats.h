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
#import <Clutch/ClutchUtils.h>
#import "/usr/include/sqlite3.h"

@interface ClutchStats : NSObject {
    sqlite3 *db;
    NSString *_databasePath;
}

+ (ClutchStats *)sharedClient;
- (void)ensureDatabaseCreated;
- (void)log:(NSString *)action withData:(NSDictionary *)data;
- (void)log:(NSString *)action;
- (NSArray *)getLogs;
- (void)deleteLogs:(NSTimeInterval)beforeOrEqualTo;

- (int)getCachedChoice:(NSString *)name;
- (void)setCachedChoice:(NSString *)name choice:(NSInteger)choice;

- (void)testChosen:(NSString *)name choice:(NSInteger)choice numChoices:(NSInteger)numChoices;
- (void)goalReached:(NSString *)name;
- (void)testFailure:(NSString *)name type:(NSString *)type;
- (void)setNumChoices:(NSInteger)numChoices forTest:(NSString *)name hasData:(BOOL)hasData;
- (NSArray *)getABLogs;
- (void)deleteABLogs:(NSTimeInterval)beforeOrEqualTo;

@property (nonatomic, retain) NSString *databasePath;

@end
