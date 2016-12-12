//
//  ClientStatsDatabase.m
//  E-Mission
//
//  Created by Kalyanaraman Shankari on 9/18/14.
//  Copyright (c) 2014 Kalyanaraman Shankari. All rights reserved.
//

#import "BEMBuiltinUserCache.h"
#import "DataUtils.h"
#import "SimpleLocation.h"
#import "Metadata.h"
#import "LocationTrackingConfig.h"
#import "ConfigManager.h"
#import "LocalNotificationManager.h"

// Table name
#define TABLE_USER_CACHE @"userCache"
#define TABLE_USER_ERROR_CACHE @"userCacheError"

// Column names
#define KEY_WRITE_TS @"write_ts"
#define KEY_READ_TS @"read_ts"
#define KEY_TIMEZONE @"timezone"
#define KEY_TYPE @"type"
#define KEY_KEY @"key"
#define KEY_PLUGIN @"plugin"
#define KEY_DATA @"data"

#define METADATA_TAG @"metadata"
#define DATA_TAG @"data"

#define SENSOR_DATA_TYPE @"sensor-data"
#define MESSAGE_TYPE @"message"
#define DOCUMENT_TYPE @"document"
#define RW_DOCUMENT_TYPE @"rw-document"
#define LOCAL_STORAGE_TYPE @"local-storage"


#define DB_FILE_NAME @"userCacheDB"

@interface BuiltinUserCache() {
    NSDictionary *statsNamesDict;
    NSString* appVersion;
}
@end

@implementation BuiltinUserCache

static BuiltinUserCache *_database;

+ (BuiltinUserCache*)database {
    if (_database == nil) {
        _database = [[BuiltinUserCache alloc] init];
    }
    return _database;
}

// TODO: Refactor this into a new database helper class?
- (id)init {
    if ((self = [super init])) {
        NSString *sqLiteDb = [self dbPath:DB_FILE_NAME];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        if (![fileManager fileExistsAtPath: sqLiteDb]) {
            // Copy existing database over to create a blank DB.
            // Apparently, we cannot create a new file there to work as the database?
            // http://stackoverflow.com/questions/10540728/creating-an-sqlite3-database-file-through-objective-c
            NSError *error = nil;
            NSString *readableDBPath = [[NSBundle mainBundle] pathForResource:DB_FILE_NAME
                                                                       ofType:nil];
            NSLog(@"Copying file from %@ to %@", readableDBPath, sqLiteDb);
            BOOL success = [[NSFileManager defaultManager] copyItemAtPath:readableDBPath
                                                                   toPath:sqLiteDb
                                                                    error:&error];
            if (!success)
            {
                NSCAssert1(0, @"Failed to create writable database file with message '%@'.", [  error localizedDescription]);
                return nil;
            }
        }
        // if we didn't have a file earlier, we just created it.
        // so we are guaranteed to always have a file when we get here
        assert([fileManager fileExistsAtPath: sqLiteDb]);
        int returnCode = sqlite3_open([sqLiteDb UTF8String], &_database);
        if (returnCode != SQLITE_OK) {
            NSLog(@"Failed to open database because of error code %d", returnCode);
            return nil;
        }
        // Read the list of valid keys
        NSString *plistStatNamesPath = [[NSBundle mainBundle] pathForResource:@"usercachekeys" ofType:@"plist"];
        statsNamesDict = [[NSDictionary alloc] initWithContentsOfFile:plistStatNamesPath];
        
        NSString *infoPath = [[NSBundle mainBundle] pathForResource:@"Info" ofType:@"plist"];
        NSDictionary *infoDict = [[NSDictionary alloc] initWithContentsOfFile:infoPath];
        appVersion = [infoDict objectForKey:@"CFBundleShortVersionString"];
    }
    return self;
}

/*
 * If we want to be really safe, we should really create methods for each of these. But I am not enthused about that level of typing.
 * While this does not provide a compile time check, it at least provides a run time check. Let's stick with that for now.
 */
- (NSString*)getStatName:(NSString*)label {
    NSString* statName = [statsNamesDict objectForKey:label];
    if (statName == NULL) {
        [NSException raise:@"unknown stat" format:@"stat %@ not defined in usercache plist", label];
    }
    return statName;
}

- (NSString*)getSelCols:(BOOL)withMetadata {
    if (withMetadata) {
        return @"*";
    } else {
        return KEY_DATA;
    }
}

- (NSString*)dbPath:(NSString*)dbName {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
                                                         NSUserDomainMask, YES);
    NSString *libraryDirectory = [paths objectAtIndex:0];
    NSString *nosync = [libraryDirectory stringByAppendingPathComponent:@"LocalDatabase"];
    NSString *dbPath = [nosync stringByAppendingPathComponent:dbName];

    NSError *err;
    if ([[NSFileManager defaultManager] fileExistsAtPath: nosync])
    {  
        NSLog(@"no cloud sync at path: %@", nosync);
        return dbPath;
    } else
    {  
        if ([[NSFileManager defaultManager] createDirectoryAtPath: nosync withIntermediateDirectories:NO attributes: nil error:&err])
        {  
            NSURL *nosyncURL = [ NSURL fileURLWithPath: nosync];
            if (![nosyncURL setResourceValue: [NSNumber numberWithBool: YES] 
                                      forKey: NSURLIsExcludedFromBackupKey error: &err]) {  
                NSLog(@"IGNORED: error setting nobackup flag in LocalDatabase directory: %@", err);
            }
            NSLog(@"no cloud sync at path: %@", nosync);
            return dbPath;
        }
        else
        {
                // fallback:
            NSLog(@"WARNING: error adding LocalDatabase directory: %@", err);
            return [libraryDirectory stringByAppendingPathComponent:dbName];
        }
    }
    return dbPath;
}

- (void)dealloc {
    sqlite3_close(_database);
}

+(double) getCurrentTimeSecs {
    return [[NSDate date] timeIntervalSince1970];
}

+(NSString*) getCurrentTimeSecsString {
    return [@([self getCurrentTimeSecs]) stringValue];
}

-(NSDictionary*)createSensorData:key write_ts:(NSDate*)write_ts timezone:(NSString*)ts data:(NSObject*)data {
    Metadata* md = [Metadata new];
    md.write_ts = [DataUtils dateToTs:write_ts];
    md.time_zone = ts;
    md.type = SENSOR_DATA_TYPE;
    md.key = [self getStatName:key];
    NSDictionary* mdDict = [DataUtils wrapperToDict:md];
    NSDictionary* dataDict = [DataUtils wrapperToDict:data];
    
    NSMutableDictionary* entry = [NSMutableDictionary new];
    [entry setObject:mdDict forKey:METADATA_TAG];
    [entry setObject:dataDict forKey:DATA_TAG];
    return entry;
}

// These are the versions intended to be used with native code
// The label is an entry into the plist, and the value is a wrapper class

-(void)putSensorData:(NSString *)label value:(NSObject *)value {
    NSString* statName = [self getStatName:label];
    [self putValue:statName value:[DataUtils wrapperToString:value] type:SENSOR_DATA_TYPE];
}

-(void)putMessage:(NSString *)label value:(NSObject *)value {
    NSString* statName = [self getStatName:label];
    [self putValue:statName value:[DataUtils wrapperToString:value] type:MESSAGE_TYPE];
}

- (void)putReadWriteDocument:(NSString*)label value:(NSObject*)value {
    NSString* statName = [self getStatName:label];
    [self putValue:statName value:[DataUtils wrapperToString:value] type:RW_DOCUMENT_TYPE];
}

// These are the versions intended to be used with the plugin
// The label is directly a string, and the value is a JSON object

-(void)putSensorData:(NSString *)label jsonValue:(NSDictionary *)value {
    [self putValue:label value:[DataUtils saveToJSONString:value] type:SENSOR_DATA_TYPE];
}

-(void)putMessage:(NSString *)label jsonValue:(NSDictionary *)value {
    [self putValue:label value:[DataUtils saveToJSONString:value] type:MESSAGE_TYPE];
}

- (void)putReadWriteDocument:(NSString*)label jsonValue:(NSDictionary *)value {
    [self putValue:label value:[DataUtils saveToJSONString:value] type:RW_DOCUMENT_TYPE];
    }
    
-(void)putValue:(NSString*)key value:(NSString*)value type:(NSString*)type {
    double currTimeSecs = [BuiltinUserCache getCurrentTimeSecs];
    
    NSString *insertStatement = [NSString stringWithFormat:@"INSERT INTO %@ (%@, %@, %@, %@, %@) VALUES (?, ?, ?, ?, ?)",
                                 TABLE_USER_CACHE, KEY_WRITE_TS, KEY_TIMEZONE, KEY_TYPE, KEY_KEY, KEY_DATA];
    sqlite3_stmt *compiledStatement;
    if(sqlite3_prepare_v2(_database, [insertStatement UTF8String], -1, &compiledStatement, NULL) == SQLITE_OK) {
        // The SQLITE_TRANSIENT is used to indicate that the raw data (userMode, tripId, sectionId
        // is not permanent data and the SQLite library should make a copy
        sqlite3_bind_double(compiledStatement, 1, currTimeSecs); // timestamp
        sqlite3_bind_text(compiledStatement, 2, [[NSTimeZone localTimeZone].name UTF8String], -1, SQLITE_TRANSIENT); // timezone
        sqlite3_bind_text(compiledStatement, 3, [type UTF8String], -1, SQLITE_TRANSIENT); // type
        sqlite3_bind_text(compiledStatement, 4, [key UTF8String], -1, SQLITE_TRANSIENT); // key
        sqlite3_bind_text(compiledStatement, 5, [value UTF8String], -1, SQLITE_TRANSIENT); // data


    }
    // Shouldn't this be within the prior if?
    // Shouldn't we execute the compiled statement only if it was generated correctly?
    // This is code copied from
    // http://stackoverflow.com/questions/2184861/how-to-insert-data-into-a-sqlite-database-in-iphone
    // Need to check from the raw sources and see where we get
    // Create a new sqlite3 database like so:
    // http://www.raywenderlich.com/902/sqlite-tutorial-for-ios-creating-and-scripting
    NSInteger execCode = sqlite3_step(compiledStatement);
    if (execCode != SQLITE_DONE) {
        NSLog(@"Got error code %ld while executing statement %@", (long)execCode, insertStatement);
    }
    sqlite3_finalize(compiledStatement);
}

-(void)putErrorValue:(Metadata*)md dataStr:(NSString*)dataStr {
    NSString *insertStatement = [NSString stringWithFormat:@"INSERT INTO %@ (%@, %@, %@, %@, %@) VALUES (?, ?, ?, ?, ?)",
                                 TABLE_USER_ERROR_CACHE, KEY_WRITE_TS, KEY_TIMEZONE, KEY_TYPE, KEY_KEY, KEY_DATA];
    sqlite3_stmt *compiledStatement;
    if(sqlite3_prepare_v2(_database, [insertStatement UTF8String], -1, &compiledStatement, NULL) == SQLITE_OK) {
        // The SQLITE_TRANSIENT is used to indicate that the raw data (userMode, tripId, sectionId
        // is not permanent data and the SQLite library should make a copy
        sqlite3_bind_double(compiledStatement, 1, md.write_ts); // timestamp
        sqlite3_bind_text(compiledStatement, 2, [md.time_zone UTF8String], -1, SQLITE_TRANSIENT); // timezone
        sqlite3_bind_text(compiledStatement, 3, [md.type UTF8String], -1, SQLITE_TRANSIENT); // type
        sqlite3_bind_text(compiledStatement, 4, [md.key UTF8String], -1, SQLITE_TRANSIENT); // key
        sqlite3_bind_text(compiledStatement, 5, [dataStr UTF8String], -1, SQLITE_TRANSIENT); // data
        
        
    }
    // Shouldn't this be within the prior if?
    // Shouldn't we execute the compiled statement only if it was generated correctly?
    // This is code copied from
    // http://stackoverflow.com/questions/2184861/how-to-insert-data-into-a-sqlite-database-in-iphone
    // Need to check from the raw sources and see where we get
    // Create a new sqlite3 database like so:
    // http://www.raywenderlich.com/902/sqlite-tutorial-for-ios-creating-and-scripting
    NSInteger execCode = sqlite3_step(compiledStatement);
    if (execCode != SQLITE_DONE) {
        NSLog(@"Got error code %ld while executing statement %@", (long)execCode, insertStatement);
    }
    sqlite3_finalize(compiledStatement);
}


/*
 * This version supports NULL cstrings
 */

- (NSString*) toNSString:(char*)cString
{
    if (cString == NULL) {
        return CLIENT_STATS_DB_NIL_VALUE;
    } else {
        return [[NSString alloc] initWithUTF8String:cString];
    }
}

- (NSArray*) readSelectResults:(NSString*) selectQuery withMetadata:(BOOL)withMetadata {
    NSMutableArray* retVal = [[NSMutableArray alloc] init];
    
    sqlite3_stmt *compiledStatement;
    NSInteger selPrepCode = sqlite3_prepare_v2(_database, [selectQuery UTF8String], -1, &compiledStatement, NULL);
    if (selPrepCode == SQLITE_OK) {
        while (sqlite3_step(compiledStatement) == SQLITE_ROW) {
            if (withMetadata) {
                NSDictionary* currEntry = [self getEntry:compiledStatement];
                [retVal addObject:currEntry];
            } else {
                NSString* currDataResult = [self toNSString:(char*)sqlite3_column_text(compiledStatement, 0)];
                [retVal addObject:currDataResult];
            }
        }
    } else {
        NSLog(@"Error code %ld while compiling query %@", (long)selPrepCode, selectQuery);
    }
    sqlite3_finalize(compiledStatement);
    return retVal;
}

- (NSArray*) getValuesForInterval:(NSString*) key tq:(TimeQuery*)tq
                             type:(NSString*)type withMetadata:(BOOL)withMetadata
{
    NSString* queryString = [NSString
                             stringWithFormat:@"SELECT %@ FROM %@ WHERE %@ = '%@' AND %@ >= %f AND %@ <= %f ORDER BY write_ts DESC",
                             [self getSelCols:withMetadata], TABLE_USER_CACHE, KEY_KEY, key,
                             tq.key, tq.startTs, tq.key, tq.endTs];
    NSArray *wrapperJSON = [self readSelectResults:queryString withMetadata:withMetadata];
    return wrapperJSON;
}

- (NSArray*) wrapClass:(NSArray*) jsonStringArr wrapperClass:(__unsafe_unretained Class)cls
{
    NSMutableArray* retWrapperArr = [NSMutableArray new];
    for (int i = 0; i < jsonStringArr.count; i++) {
        [retWrapperArr addObject:[DataUtils stringToWrapper:jsonStringArr[i] wrapperClass:cls]];
    }
    return retWrapperArr;
}

- (NSArray*) wrapJSON:(NSArray*) jsonStringOrEntryArr withMetadata:(BOOL)withMetadata
{
    NSMutableArray* retWrapperArr = [NSMutableArray new];
    for (int i = 0; i < jsonStringOrEntryArr.count; i++) {
        if (withMetadata) {
            [retWrapperArr addObject:jsonStringOrEntryArr[i]];
        } else {
            [retWrapperArr addObject:[DataUtils loadFromJSONString:jsonStringOrEntryArr[i]]];
        }
    }
    return retWrapperArr;
}

// These are the versions intended to be used with native code
// The label is an entry into the plist, and the value is a wrapper class

- (NSArray*) getSensorDataForInterval:(NSString*) key tq:(TimeQuery*)tq wrapperClass:(__unsafe_unretained Class)cls
{
    return [self wrapClass:[self getValuesForInterval:[self getStatName:key] tq:tq
                                                 type:SENSOR_DATA_TYPE withMetadata:NO] wrapperClass:cls];
}

- (NSArray*) getMessageForInterval:(NSString*) key tq:(TimeQuery*)tq wrapperClass:(__unsafe_unretained Class)cls {
    return [self wrapClass:[self getValuesForInterval:[self getStatName:key] tq:tq
                                                 type:MESSAGE_TYPE withMetadata:NO] wrapperClass:cls];
}

- (NSArray*) getSensorDataForInterval:(NSString*) key tq:(TimeQuery*)tq withMetadata:(BOOL)withMetadata
{
    return [self wrapJSON:[self getValuesForInterval:key tq:tq type:SENSOR_DATA_TYPE withMetadata:withMetadata] withMetadata:withMetadata];
}

- (NSArray*) getMessageForInterval:(NSString*) key tq:(TimeQuery*)tq withMetadata:(BOOL)withMetadata {
    return [self wrapJSON:[self getValuesForInterval:key tq:tq type:MESSAGE_TYPE withMetadata:withMetadata]
             withMetadata:withMetadata];
}

- (NSArray*) getLastValues:(NSString*) key nEntries:(int)nEntries
                      type:(NSString*)type withMetadata:(BOOL)withMetadata
{
    /*
     * Note: the first getKey(keyRes) is the key of the message (e.g. 'background/location').
     * The second getKey(tq.keyRes) is the key of the time query (e.g. 'write_ts')
     */
    NSString* queryString = [NSString
                             stringWithFormat:@"SELECT %@ FROM %@ WHERE %@ = '%@' AND %@ = '%@' ORDER BY write_ts DESC LIMIT %d",
                             [self getSelCols:withMetadata], TABLE_USER_CACHE, KEY_KEY, key, KEY_TYPE, type, nEntries];
    NSArray *wrapperJSON = [self readSelectResults:queryString withMetadata:withMetadata];
    return wrapperJSON;
}

- (NSArray*) getLastSensorData:(NSString*) key nEntries:(int)nEntries wrapperClass:(Class)cls {
    return [self wrapClass:[self getLastValues:[self getStatName:key] nEntries:nEntries
                                          type:SENSOR_DATA_TYPE withMetadata:NO] wrapperClass:cls];
}

- (NSArray*) getLastMessage:(NSString*)key nEntries:(int)nEntries wrapperClass:(Class)cls {
    return [self wrapClass:[self getLastValues:[self getStatName:key] nEntries:nEntries
                                          type:MESSAGE_TYPE withMetadata:NO] wrapperClass:cls];
}

- (NSArray*) getLastSensorData:(NSString*) key nEntries:(int)nEntries withMetadata:(BOOL)withMetadata {
    return [self wrapJSON:[self getLastValues:[self getStatName:key] nEntries:nEntries
                                         type:SENSOR_DATA_TYPE withMetadata:withMetadata]
             withMetadata:withMetadata];
}

- (NSArray*) getLastMessage:(NSString*)key nEntries:(int)nEntries withMetadata:(BOOL)withMetadata {
    return [self wrapJSON:[self getLastValues:[self getStatName:key] nEntries:nEntries
                                         type:MESSAGE_TYPE withMetadata:withMetadata]
             withMetadata:withMetadata];
}

-(NSObject*) getDocument:(NSString*)key wrapperClass:(Class)cls {
    NSString* dataStr = [self getDocumentStringOrEntry:[self getStatName:key] withMetadata:NO];
    if (dataStr != NULL) {
        return [DataUtils stringToWrapper:dataStr wrapperClass:cls];
    }
    return NULL;
}

-(NSDictionary*) getDocument:(NSString*)key withMetadata:(BOOL) withMetadata {
    id dataStrOrEntry = [self getDocumentStringOrEntry:key withMetadata:withMetadata];
    if (dataStrOrEntry != NULL) {
        if (withMetadata) {
            return dataStrOrEntry;
        } else {
            return [DataUtils loadFromJSONString:dataStrOrEntry];
        }
    }
    return NULL;
}

- (id) getDocumentStringOrEntry:(NSString*)key withMetadata:(BOOL)withMetadata
{
    // Since we are ordering the results by write_ts, we expect the following behavior:
    // - only RW_DOCUMENT -> it is returned
    // - only DOCUMENT -> it is returned
    // - both RW_DOCUMENT and DOCUMENT, and DOCUMENT is generated from RW_DOCUMENT -> DOCUMENT is returned
    // since it has the later timestamp
    // - both RW_DOCUMENT and DOCUMENT, and RW_DOCUMENT is created by cloning DOCUMENT -> RW_DOCUMENT
    // since it has the later timestamp
    // If any of the assumptions in the RW_DOCUMENT and DOCUMENT case are violated, we need to change this
    // to read both values and look at their types
    NSString* queryString = [NSString
                             stringWithFormat:@"SELECT %@ FROM %@ WHERE %@ = '%@' AND (%@ = '%@' OR %@ = '%@') ORDER BY write_ts DESC LIMIT 1",
                             [self getSelCols:withMetadata], TABLE_USER_CACHE, KEY_KEY, key, KEY_TYPE, DOCUMENT_TYPE, KEY_TYPE, RW_DOCUMENT_TYPE];
    NSArray *wrapperJSON = [self readSelectResults:queryString withMetadata:withMetadata];
    assert((wrapperJSON.count == 0) || (wrapperJSON.count == 1));
    if (wrapperJSON.count == 0) {
        return NULL;
    } else {
        return wrapperJSON[0];
    }
}

-(double)getTsOfLastTransition {
    NSString* whereClause = @" '%_transition_:_T_TRIP_ENDED_%' ORDER BY write_ts DESC LIMIT 1";
    NSString* selectQuery = [NSString stringWithFormat:@"SELECT write_ts FROM %@ WHERE %@ = '%@' AND %@ LIKE %@", TABLE_USER_CACHE, KEY_KEY,
                             [self getStatName:@"key.usercache.transition"], KEY_DATA, whereClause];

    NSLog(@"selectQuery = %@", selectQuery);
    sqlite3_stmt *compiledStatement;
    NSInteger selPrepCode = sqlite3_prepare_v2(_database, [selectQuery UTF8String], -1,
                                               &compiledStatement, NULL);
    if (selPrepCode == SQLITE_OK) {
        if (sqlite3_step(compiledStatement) == SQLITE_ROW) {
            return sqlite3_column_double(compiledStatement, 0);
        } else {
            NSLog(@"There are no T_TRIP_ENDED entries in the usercache. A sync must have just completed.");
            return -1;
        }
    } else {
        NSLog(@"Error %ld while compiling query %@", selPrepCode, selectQuery);
        return -1;
    }
}

-(double)getTsOfLastEntry {
    NSString* selectQuery = [NSString stringWithFormat:@"SELECT write_ts FROM %@ ORDER BY write_ts DESC LIMIT 1", TABLE_USER_CACHE];
    
    NSLog(@"selectQuery = %@", selectQuery);
    sqlite3_stmt *compiledStatement;
    NSInteger selPrepCode = sqlite3_prepare_v2(_database, [selectQuery UTF8String], -1,
                                               &compiledStatement, NULL);
    if (selPrepCode == SQLITE_OK) {
        if (sqlite3_step(compiledStatement) == SQLITE_ROW) {
            return sqlite3_column_double(compiledStatement, 0);
        } else {
            NSLog(@"There are no T_TRIP_ENDED entries in the usercache. A sync must have just completed.");
            return -1;
        }
    } else {
        NSLog(@"Error %ld while compiling query %@", (long)selPrepCode, selectQuery);
        return -1;
    }
}

-(double)getLastTs {
    if ([ConfigManager instance].is_duty_cycling) {
        return [self getTsOfLastTransition];
    } else {
        return [self getTsOfLastEntry];
    }
}


/*
 * LocalStorage interface
 */

// These are the versions intended temporary configurations that need to be shared between
// javascript and native. Functions as standard k-v store, no wrapper classes, no object interface.
- (void)putLocalStorage:(NSString*)label jsonValue:(NSDictionary *)value {
    [self putValue:label value:[DataUtils saveToJSONString:value] type:LOCAL_STORAGE_TYPE];
}

- (NSMutableDictionary*) getLocalStorage:(NSString*) key withMetadata:(BOOL)withMetadata {
    TimeQuery* tq = [BuiltinUserCache getAllTimeQuery];
    NSArray* wrappedJSON = [self wrapJSON:[self getValuesForInterval:key tq:tq type:LOCAL_STORAGE_TYPE withMetadata:withMetadata] withMetadata:withMetadata];
    if ([wrappedJSON count] == 0) {
        return NULL;
    } else {
        return [NSMutableDictionary dictionaryWithDictionary:[wrappedJSON objectAtIndex:0]];
    }
}

- (void) removeLocalStorage:(NSString*) key {
    NSString* deleteQuery = [NSString stringWithFormat:@"DELETE FROM %@ WHERE (%@ = '%@' AND %@ = '%@')",
                             TABLE_USER_CACHE, KEY_KEY, key, KEY_TYPE, LOCAL_STORAGE_TYPE];
    [LocalNotificationManager addNotification:[NSString stringWithFormat:@"while removing local storage, deleteQuery = %@", deleteQuery] showUI:FALSE];
    [self clearQuery:deleteQuery];
}

/*
 * Since we are using distance based filtering for iOS, and there is no reliable background sync, we push the data
 * only when we detect a trip end. If this is done through push notifications, we do so by looking to see if the
 * last location point was generated more than threshold ago. If this is done through visit detection, then we don't
 * use any location points. So we assume that we can just send all the points over to the server and don't have to 
 * find the last transition to trip end like we do on android.
 */

- (NSDictionary*) getEntry:(sqlite3_stmt*) curr_stmt_result {
            // Remember that while reading results, the index starts from 0
            Metadata* md = [Metadata new];
    md.write_ts = sqlite3_column_double(curr_stmt_result, 0);
    md.read_ts = sqlite3_column_double(curr_stmt_result, 1);
    md.time_zone = [self toNSString:(char*)sqlite3_column_text(curr_stmt_result, 2)];
    md.type = [self toNSString:(char*)sqlite3_column_text(curr_stmt_result, 3)];
    md.key = [self toNSString:(char*)sqlite3_column_text(curr_stmt_result, 4)];
    md.plugin = [self toNSString:(char*)sqlite3_column_text(curr_stmt_result, 5)];
            NSDictionary* mdDict = [DataUtils wrapperToDict:md];
    NSString* dataStr = [self toNSString:(char*)sqlite3_column_text(curr_stmt_result, 6)];
            NSDictionary* dataDict = [DataUtils loadFromJSONString:dataStr];
            
            if (dataDict == NULL) {
                // data could not be parsed as valid JSON, storing into the error database
                [LocalNotificationManager addNotification:[NSString stringWithFormat:@"Error while converting data string %@ to JSON, skipping it", dataStr] showUI:FALSE];
                // TODO: Re-enable once we resolve
                // https://github.com/e-mission/cordova-usercache/issues/7
                // [self putErrorValue:md dataStr:dataStr];
        return NULL;
            } else {
            NSMutableDictionary* entry = [NSMutableDictionary new];
            [entry setObject:mdDict forKey:METADATA_TAG];
            [entry setObject:dataDict forKey:DATA_TAG];
        return entry;
    }
}

- (NSArray*) syncPhoneToServer {
    double lastTripEndTs = [self getLastTs];
    if (lastTripEndTs < 0) {
        [LocalNotificationManager addNotification:[NSString stringWithFormat:@"lastTripEndTs = %f, nothing to push, returning", lastTripEndTs] showUI:FALSE];
        // we don't have a completed trip, we don't want to push anything yet
        return [NSArray new];
    }
    
    NSString *retrieveDataQuery = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@='%@' OR %@='%@' OR %@='%@' ORDER BY %@ LIMIT 10000", TABLE_USER_CACHE, KEY_TYPE, MESSAGE_TYPE, KEY_TYPE, SENSOR_DATA_TYPE, KEY_TYPE, RW_DOCUMENT_TYPE, KEY_WRITE_TS];
    NSMutableArray *resultArray = [NSMutableArray new];
            
    sqlite3_stmt *compiledStatement;
    NSInteger selPrepCode = sqlite3_prepare_v2(_database, [retrieveDataQuery UTF8String], -1,
                                               &compiledStatement, NULL);
    if (selPrepCode == SQLITE_OK) {
        while (sqlite3_step(compiledStatement) == SQLITE_ROW) {
            NSDictionary* entry = [self getEntry:compiledStatement];
            if (entry != NULL) {
            [resultArray addObject:entry];
        }
        }
    } else {
        NSLog(@"Error code %ld while compiling query %@", (long)selPrepCode, retrieveDataQuery);
    }

    /*
     * If there are no stats, there's no need to send any metadata either
     */
    
    sqlite3_finalize(compiledStatement);
    return resultArray;
}

- (void)syncServerToPhone:(NSArray*)documentArray {
    for (NSDictionary* currDoc in documentArray) {
        Metadata* md = [Metadata new];
        [DataUtils dictToWrapper:[currDoc objectForKey:METADATA_TAG] wrapper:md];
        NSDictionary* dataDict = [currDoc objectForKey:DATA_TAG];
        NSString *insertStatement = [NSString stringWithFormat:@"INSERT INTO %@ (%@, %@, %@, %@, %@) VALUES (?, ?, ?, ?, ?)",
                                 TABLE_USER_CACHE, KEY_WRITE_TS, KEY_READ_TS, KEY_TYPE, KEY_KEY, KEY_DATA];
        sqlite3_stmt *compiledStatement;
        NSInteger prepareCode = sqlite3_prepare_v2(_database, [insertStatement UTF8String], -1, &compiledStatement, NULL);
        NSLog(@"for statement %@, prepareCode = %ld, error = %s", insertStatement, (long)prepareCode, sqlite3_errmsg(_database));
        if(prepareCode== SQLITE_OK) {
            // The SQLITE_TRANSIENT is used to indicate that the raw data (userMode, tripId, sectionId
            // is not permanent data and the SQLite library should make a copy
            sqlite3_bind_double(compiledStatement, 1, md.write_ts); // timestamp
            sqlite3_bind_double(compiledStatement, 2, md.read_ts); // timezone
            sqlite3_bind_text(compiledStatement, 3, [md.type UTF8String], -1, SQLITE_TRANSIENT); // type
            sqlite3_bind_text(compiledStatement, 4, [md.key UTF8String], -1, SQLITE_TRANSIENT); // key
//            sqlite3_bind_text(compiledStatement, 5, [md.plugin UTF8String], -1, SQLITE_TRANSIENT); // key
            sqlite3_bind_text(compiledStatement, 5, [[DataUtils saveToJSONString:dataDict] UTF8String], -1, SQLITE_TRANSIENT); // data
        
        }
        // Shouldn't this be within the prior if?
        // Shouldn't we execute the compiled statement only if it was generated correctly?
        // This is code copied from
        // http://stackoverflow.com/questions/2184861/how-to-insert-data-into-a-sqlite-database-in-iphone
        // Need to check from the raw sources and see where we get
        // Create a new sqlite3 database like so:
        // http://www.raywenderlich.com/902/sqlite-tutorial-for-ios-creating-and-scripting
        NSInteger execCode = sqlite3_step(compiledStatement);
        if (execCode != SQLITE_DONE) {
            NSLog(@"Got error code %ld while executing statement %@", (long)execCode, insertStatement);
        }
        sqlite3_finalize(compiledStatement);
    }
}

+ (TimeQuery*) getTimeQuery:(NSArray*)pointList {
    assert(pointList.count != 0);
    Metadata* startMd = [Metadata new];
    [DataUtils dictToWrapper:[pointList[0] objectForKey:METADATA_TAG] wrapper:startMd];
    double start_ts = startMd.write_ts;
    
    Metadata* endMd = [Metadata new];
    [DataUtils dictToWrapper:[pointList[pointList.count - 1] objectForKey:METADATA_TAG] wrapper:endMd];
    double end_ts = endMd.write_ts;

    // Start slightly before and end slightly after to make sure that we get all entries
    TimeQuery* tq = [TimeQuery new];
    tq.key = KEY_WRITE_TS;
    tq.startTs = start_ts - 1;
    tq.endTs = end_ts + 1;
    return tq;
}

+ (TimeQuery*) getAllTimeQuery {
    TimeQuery* tq = [TimeQuery new];
    tq.key = KEY_WRITE_TS;
    tq.startTs = 0;
    tq.endTs = [DataUtils dateToTs:[NSDate date]];
    return tq;
}

+ (NSString*) getTimezone:(NSDictionary*)entry {
    Metadata* md = [Metadata new];
    [DataUtils dictToWrapper:[entry objectForKey:METADATA_TAG] wrapper:md];
    return md.time_zone;
}

+ (NSDate*) getWriteTs:(NSDictionary *)entry {
    Metadata* md = [Metadata new];
    [DataUtils dictToWrapper:[entry objectForKey:METADATA_TAG] wrapper:md];
    return [DataUtils dateFromTs:md.write_ts];
}

/* TODO: Consider refactoring this along with the code in TripSectionDB to have generic read code.
 * Unfortunately, the code in TripSectionDB sometimes reads blobs, which require a different read method,
 * so this refactoring is likely to be non-trivial
 */

- (void)clearEntries:(TimeQuery*)tq {
    [LocalNotificationManager addNotification:[NSString stringWithFormat:@"Clearing entries for timequery %f -> %f",
                                               tq.startTs, tq.endTs] showUI:FALSE];
    // Don't delete read-write documents just yet - they will be deleted when we get the overriden document
    NSString* deleteQuery = [NSString stringWithFormat:@"DELETE FROM %@ WHERE (%@ > %f AND %@ < %f AND %@ != '%@' AND %@ != '%@' AND %@ != '%@')",
                             TABLE_USER_CACHE, tq.key, tq.startTs, tq.key, tq.endTs, KEY_TYPE, RW_DOCUMENT_TYPE, KEY_TYPE, DOCUMENT_TYPE, KEY_TYPE, LOCAL_STORAGE_TYPE];
    [LocalNotificationManager addNotification:[NSString stringWithFormat:@"deleteQuery = %@", deleteQuery] showUI:FALSE];
    [self clearQuery:deleteQuery];
}

- (void) clearSupersededRWDocs:(TimeQuery*) tq {
    // Also, clear all rw-documents that have been superseded by other rw-documents on the phone
    // in particular, always retain the most recent rw document and do not delete it, even if we get a document
    // from the server for it.
    [LocalNotificationManager addNotification:[NSString stringWithFormat:@"clearing overridden rw-documents"] showUI:FALSE];
    // SELECT DISTINCT(key) FROM userCache WHERE type = 'rw-document';
    NSString* checkQuery = [NSString stringWithFormat:@"SELECT DISTINCT(%@) FROM %@ WHERE %@ = '%@'",
                            KEY_KEY, TABLE_USER_CACHE, KEY_TYPE, RW_DOCUMENT_TYPE];
    NSArray* docResults = [self readSelectResults:checkQuery withMetadata:NO];
    for (int i=0; i < docResults.count; i++) {
        NSString* currKey = docResults[i];
        NSString* selectQuery = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@ = '%@' AND %@ = '%@' AND %@ < MIN(%.0f, (SELECT MAX(%@) FROM %@ WHERE (%@ = '%@' AND %@ = '%@')))",
                                 TABLE_USER_CACHE, KEY_KEY, currKey, KEY_TYPE, RW_DOCUMENT_TYPE, KEY_WRITE_TS, tq.endTs, KEY_WRITE_TS, TABLE_USER_CACHE, KEY_KEY, currKey, KEY_TYPE, RW_DOCUMENT_TYPE];
        [LocalNotificationManager addNotification:[NSString stringWithFormat:@"selectQuery = %@", selectQuery] showUI:FALSE];
        NSArray* toDeleteDocs = [self readSelectResults:selectQuery withMetadata:YES];
        for (int j = 0; j < toDeleteDocs.count; j++) {
            [LocalNotificationManager addNotification:[NSString stringWithFormat:@"At index %d, about to delete = %@", j, toDeleteDocs[j]] showUI:FALSE];
        }
        // DELETE FROM TABLE_USER_CACHE WHERE type = 'rw-document) AND
        // write_ts < MIN(tq.endTs, (SELECT MAX(write_ts) FROM userCache WHERE (key = '...' AND TYPE = 'rw-document')))
        NSString* rwDocDeleteQuery = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@ = '%@' AND %@ = '%@' AND %@ < MIN(%.0f, (SELECT MAX(%@) FROM %@ WHERE (%@ = '%@' AND %@ = '%@')))",
                                      TABLE_USER_CACHE, KEY_KEY, currKey, KEY_TYPE, RW_DOCUMENT_TYPE, KEY_WRITE_TS, tq.endTs, KEY_WRITE_TS, TABLE_USER_CACHE, KEY_KEY, currKey, KEY_TYPE, RW_DOCUMENT_TYPE];
    [LocalNotificationManager addNotification:[NSString stringWithFormat:@"rwDocDeleteQuery = %@", rwDocDeleteQuery] showUI:FALSE];
    [self clearQuery:rwDocDeleteQuery];
    }
}

/*
 * Hack to ensure that we have an rw-document that cannot be deleted for every config. This should make existing installs become 
 * similar to new installs and ensure that https://github.com/e-mission/cordova-jwt-auth/issues/8#issuecomment-260214971 does
 * not recur.
 *
 * Therefore, it is sufficient to handle the existing possible config documents. This can be deleted after everybody has upgraded
 * to the most recent version.
 */

- (void) convertConfigToRW:(TimeQuery*) tq {
    NSArray* configKeys = @[@"config/consent", @"config/sync_config", @"config/sensor_config"];
    for (int i = 0; i < configKeys.count; i++) {
        NSString* currKey = configKeys[i];
        [LocalNotificationManager addNotification:[NSString stringWithFormat:@"About to check rw state for config %@", currKey]];
        // SELECT DATA FROM userCache WHERE KEY = currKey and TYPE = 'rw-document';
        NSString* currQuery = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@ = '%@' AND %@ = '%@'",
                               TABLE_USER_CACHE, KEY_KEY, currKey, KEY_TYPE, @"rw-document"];
        NSArray* checkResults = [self readSelectResults:currQuery withMetadata:YES];
        if ([checkResults count] > 0) {
            [LocalNotificationManager addNotification:[NSString stringWithFormat:@"Already have rw-document for key %@, nothing to fix", currKey]];
        } else {
            NSDictionary* currDoc = [self getDocument:currKey withMetadata:YES];
            if (currDoc == NULL) {
                [LocalNotificationManager addNotification:[NSString stringWithFormat:@"For key %@, found no document found either, skipping", currKey]];
            } else {
                [LocalNotificationManager addNotification:[NSString stringWithFormat:@"For key %@, found document with write_ts = %@, but not rw-document, changing...", currDoc[@"metadata"][@"write_ts"], currKey]];
                [self putReadWriteDocument:currKey jsonValue:currDoc[KEY_DATA]];
                // I could try to update the rw-document here to match the original write_ts, but then I'd have to write another SQL
                // statement, adding complexity to what it essentially a one-time hack. I also don't remember whether the write_ts
                // from the server was the same as the write_ts of the original rw-document. Let's just stick with this for now...
            }
        }
    }
}

- (void) clearObsoleteDocs:(TimeQuery*)tq {
    // Now, clear all documents. If the documents are still valid, they will be
    // pulled from the server. If they are not, they should be cleared up so that
    // we don't grow forever.
    // See https://github.com/e-mission/cordova-usercache/issues/24
    [self convertConfigToRW:tq];
    NSString* deleteDocQuery = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@ = '%@'",
                                TABLE_USER_CACHE, KEY_TYPE, DOCUMENT_TYPE];
    [LocalNotificationManager addNotification:[NSString stringWithFormat:@"deleteDocQuery = %@", deleteDocQuery] showUI:FALSE];
    [self clearQuery:deleteDocQuery];
}

- (void) checkAfterPull {
    NSString* checkQuery = [NSString stringWithFormat:@"SELECT DISTINCT(%@) FROM %@", KEY_KEY, TABLE_USER_CACHE];
    NSArray* checkResults = [self readSelectResults:checkQuery withMetadata:NO];
    [LocalNotificationManager addNotification:[NSString stringWithFormat:@"After clear complete, cache has entries %@", [checkResults componentsJoinedByString:@", "]] showUI:FALSE];
}

- (void)invalidateCache:(TimeQuery *)tq
{
    // Invalidate the cache, i.e. entries of type DOCUMENT
    NSString* deleteQuery = [NSString stringWithFormat:@"DELETE FROM %@ WHERE (%@ > %f AND %@ < %f AND %@ == '%@')",
                             TABLE_USER_CACHE, tq.key, tq.startTs, tq.key, tq.endTs, KEY_TYPE, DOCUMENT_TYPE];
    [self clearQuery:deleteQuery];
}

- (void)clear {
    NSString *deleteQuery = [NSString stringWithFormat:@"DELETE FROM %@", TABLE_USER_CACHE];
    [self clearQuery:deleteQuery];
}

- (void)clearQuery:(NSString*)deleteQuery {
    sqlite3_stmt *compiledStatement;
    NSInteger delPrepCode = sqlite3_prepare_v2(_database, [deleteQuery UTF8String], -1, &compiledStatement, NULL);
    if (delPrepCode == SQLITE_OK) {
        sqlite3_step(compiledStatement);
    }
    sqlite3_finalize(compiledStatement);
}

@end
