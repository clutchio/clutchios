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

#import <Clutch/ClutchStats.h>
#import "ClutchJSONKit.h"

@implementation ClutchStats

@synthesize databasePath = _databasePath;

+ (ClutchStats *)sharedClient {
    static ClutchStats *_sharedClient = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _sharedClient = [[self alloc] init];
        [_sharedClient ensureDatabaseCreated];
    });
    return _sharedClient;
}

- (void)ensureDatabaseCreated {
    // Get the documents directory
    NSArray *dirPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docsDir = [dirPaths objectAtIndex:0];
    // Build the path to the database file
    self.databasePath = [docsDir stringByAppendingPathComponent: @"clutch.db"];
    
    const char *dbpath = [self.databasePath UTF8String];
    if(sqlite3_open(dbpath, &db) == SQLITE_OK) {
        char *errMsg;
        
        const char *statssql = "CREATE TABLE IF NOT EXISTS stats (uuid TEXT, ts REAL, action TEXT, data TEXT)";
        if(sqlite3_exec(db, statssql, NULL, NULL, &errMsg) != SQLITE_OK) {
            NSLog(@"Failed to create Clutch stats table\n");
        }
        
        const char *abcachesql = "CREATE TABLE IF NOT EXISTS abcache (name TEXT, choice INTEGER)";
        if(sqlite3_exec(db, abcachesql, NULL, NULL, &errMsg) != SQLITE_OK) {
            NSLog(@"Failed to create Clutch abcache table\n");
        }
        
        const char *ablogsql = "CREATE TABLE IF NOT EXISTS ablog (uuid TEXT, ts REAL, data TEXT)";
        if(sqlite3_exec(db, ablogsql, NULL, NULL, &errMsg) != SQLITE_OK) {
            NSLog(@"Failed to create Clutch ablog table\n");
        }
        
        sqlite3_close(db);
        
    } else {
        NSLog(@"Failed to open/create Clutch stats database\n");
    }
}

/* CLUTCHSTATS */

- (void)log:(NSString *)action withData:(NSDictionary *)data {
    sqlite3_stmt *statement;
    if(sqlite3_open([self.databasePath UTF8String], &db) == SQLITE_OK) {
        NSString *sql = @"INSERT INTO stats (uuid, ts, action, data) VALUES (?, ?, ?, ?)";
        sqlite3_prepare_v2(db, [sql UTF8String], -1, &statement, NULL);
        sqlite3_bind_text(statement, 1, [[ClutchUtils getUUID] UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_double(statement, 2, [[NSDate date] timeIntervalSince1970]);
        sqlite3_bind_text(statement, 3, [action UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(statement, 4, [[ClutchJSONEncoder jsonString:data] UTF8String], -1, SQLITE_TRANSIENT);
        if(sqlite3_step(statement) != SQLITE_DONE) {
            NSLog(@"Failed to log Clutch stat: %@\n", action);
        }
        sqlite3_finalize(statement);
        sqlite3_close(db);
    }
}

- (void)log:(NSString *)action {
    [self log:action withData:nil];
}

- (NSArray *)getLogs {
    NSMutableArray *resp = [NSMutableArray array];
    
    sqlite3_stmt *statement;
    if(sqlite3_open([self.databasePath UTF8String], &db) == SQLITE_OK) {
        NSString *sql = @"SELECT uuid, ts, action, data FROM stats ORDER BY ts";
        if(sqlite3_prepare_v2(db, [sql UTF8String], -1, &statement, NULL) == SQLITE_OK) {
            while(sqlite3_step(statement) == SQLITE_ROW) {
                NSString *uuid = [[NSString alloc] initWithUTF8String:(const char *)sqlite3_column_text(statement, 0)];
                NSNumber *ts = [NSNumber numberWithDouble:sqlite3_column_double(statement, 1)];
                NSString *action = [[NSString alloc] initWithUTF8String:(const char *)sqlite3_column_text(statement, 2)];
                const unsigned char *dataChars = sqlite3_column_text(statement, 3);
                NSString *data = nil;
                if(dataChars != NULL) {
                    data = [[NSString alloc] initWithUTF8String:(const char*)dataChars];
                }
                
                id decodedData;
                if(data) {
                    size_t dataLength = strlen((const char *)dataChars);
                    decodedData = [[ClutchJSONDecoder decoder] objectWithUTF8String:dataChars length:dataLength error:nil];
                } else {
                    decodedData = [NSNull null];
                }
                
                NSDictionary *obj = [NSDictionary dictionaryWithObjectsAndKeys:
                                     uuid, @"uuid",
                                     ts, @"ts",
                                     action, @"action",
                                     decodedData, @"data",
                                     nil];
                [resp addObject:obj];
                [action release];
                if(dataChars != NULL) {
                    [data release];
                }
            }
            sqlite3_finalize(statement);
        }
        sqlite3_close(db);
    }
    
    return resp;
}

- (void)deleteLogs:(NSTimeInterval)beforeOrEqualTo {
    sqlite3_stmt *statement;
    if(sqlite3_open([self.databasePath UTF8String], &db) == SQLITE_OK) {
        NSString *sql = @"DELETE FROM stats WHERE ts <= ?";
        sqlite3_prepare_v2(db, [sql UTF8String], -1, &statement, NULL);
        sqlite3_bind_double(statement, 1, beforeOrEqualTo);
        if(sqlite3_step(statement) != SQLITE_DONE) {
            NSLog(@"Failed to delete Clutch logs\n");
        }
        sqlite3_finalize(statement);
        sqlite3_close(db);
    }
}

/* AB CACHE */

- (int)getCachedChoice:(NSString *)name {
    NSInteger resp = -1;
    sqlite3_stmt *statement;
    if(sqlite3_open([self.databasePath UTF8String], &db) == SQLITE_OK) {
        NSString *sql = @"SELECT choice FROM abcache WHERE name = ?";
        sqlite3_prepare_v2(db, [sql UTF8String], -1, &statement, NULL);
        sqlite3_bind_text(statement, 1, [name UTF8String], -1, SQLITE_TRANSIENT);
        while(sqlite3_step(statement) == SQLITE_ROW) {
            resp = sqlite3_column_int(statement, 0);
        }
        sqlite3_finalize(statement);
        sqlite3_close(db);
    }
    return resp;
}

- (void)setCachedChoice:(NSString *)name choice:(NSInteger)choice {
    sqlite3_stmt *statement;
    if(sqlite3_open([self.databasePath UTF8String], &db) == SQLITE_OK) {
        NSString *sql = @"INSERT INTO abcache (name, choice) VALUES (?, ?)";
        sqlite3_prepare_v2(db, [sql UTF8String], -1, &statement, NULL);
        sqlite3_bind_text(statement, 1, [name UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_int(statement, 2, choice);
        if(sqlite3_step(statement) != SQLITE_DONE) {
            NSLog(@"Failed to insert cached choice\n");
        }
        sqlite3_finalize(statement);
        sqlite3_close(db);
    }
}

/* AB LOG */

- (void)logWithABData:(NSDictionary *)data {
    sqlite3_stmt *statement;
    if(sqlite3_open([self.databasePath UTF8String], &db) == SQLITE_OK) {
        NSString *sql = @"INSERT INTO ablog (uuid, ts, data) VALUES (?, ?, ?)";
        sqlite3_prepare_v2(db, [sql UTF8String], -1, &statement, NULL);
        sqlite3_bind_text(statement, 1, [[ClutchUtils getUUID] UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_double(statement, 2, [[NSDate date] timeIntervalSince1970]);
        sqlite3_bind_text(statement, 3, [[ClutchJSONEncoder jsonString:data] UTF8String], -1, SQLITE_TRANSIENT);
        if(sqlite3_step(statement) != SQLITE_DONE) {
            NSLog(@"Failed to log AB data: %@\n", data);
        }
        sqlite3_finalize(statement);
        sqlite3_close(db);
    }
}

- (void)testChosen:(NSString *)name choice:(NSInteger)choice numChoices:(NSInteger)numChoices {
    NSDictionary *data = [NSDictionary dictionaryWithObjectsAndKeys:
                          @"test", @"action",
                          [NSNumber numberWithInteger:choice], @"choice",
                          [NSNumber numberWithInteger:numChoices], @"num_choices",
                          name, @"name",
                          nil];
    [self logWithABData:data];
}

- (void)goalReached:(NSString *)name {
    NSDictionary *data = [NSDictionary dictionaryWithObjectsAndKeys:
                          @"goal", @"action",
                          name, @"name",
                          nil];
    [self logWithABData:data];
}

- (void)testFailure:(NSString *)name type:(NSString *)type {
    NSDictionary *data = [NSDictionary dictionaryWithObjectsAndKeys:
                          @"failure", @"action",
                          name, @"name",
                          type, @"type",
                          nil];
    [self logWithABData:data];
}

- (void)setNumChoices:(NSInteger)numChoices forTest:(NSString *)name hasData:(BOOL)hasData {
    NSDictionary *data = [NSDictionary dictionaryWithObjectsAndKeys:
                          @"num-choices", @"action",
                          [NSNumber numberWithInteger:numChoices], @"num_choices",
                          name, @"name",
                          [NSNumber numberWithBool:hasData], @"has_data",
                          nil];
    [self logWithABData:data];
}

- (NSArray *)getABLogs {
    NSMutableArray *resp = [NSMutableArray array];
    
    sqlite3_stmt *statement;
    if(sqlite3_open([self.databasePath UTF8String], &db) == SQLITE_OK) {
        NSString *sql = @"SELECT uuid, ts, data FROM ablog ORDER BY ts";
        if(sqlite3_prepare_v2(db, [sql UTF8String], -1, &statement, NULL) == SQLITE_OK) {
            while(sqlite3_step(statement) == SQLITE_ROW) {
                NSString *uuid = [[NSString alloc] initWithUTF8String:(const char *)sqlite3_column_text(statement, 0)];
                NSNumber *ts = [NSNumber numberWithDouble:sqlite3_column_double(statement, 1)];
                const unsigned char *dataChars = sqlite3_column_text(statement, 2);
                NSString *data = nil;
                if(dataChars != NULL) {
                    data = [[NSString alloc] initWithUTF8String:(const char*)dataChars];
                }
                
                id decodedData;
                if(data) {
                    size_t dataLength = strlen((const char *)dataChars);
                    decodedData = [[ClutchJSONDecoder decoder] objectWithUTF8String:dataChars length:dataLength error:nil];
                } else {
                    decodedData = [NSNull null];
                }
                
                NSDictionary *obj = [NSDictionary dictionaryWithObjectsAndKeys:
                                     uuid, @"uuid",
                                     ts, @"ts",
                                     decodedData, @"data",
                                     nil];
                [resp addObject:obj];
                if(dataChars != NULL) {
                    [data release];
                }
            }
            sqlite3_finalize(statement);
        }
        sqlite3_close(db);
    }
    
    return resp;
}

- (void)deleteABLogs:(NSTimeInterval)beforeOrEqualTo {
    sqlite3_stmt *statement;
    if(sqlite3_open([self.databasePath UTF8String], &db) == SQLITE_OK) {
        NSString *sql = @"DELETE FROM ablog WHERE ts <= ?";
        sqlite3_prepare_v2(db, [sql UTF8String], -1, &statement, NULL);
        sqlite3_bind_double(statement, 1, beforeOrEqualTo);
        if(sqlite3_step(statement) != SQLITE_DONE) {
            NSLog(@"Failed to delete AB logs\n");
        }
        sqlite3_finalize(statement);
        sqlite3_close(db);
    }
}

@end
