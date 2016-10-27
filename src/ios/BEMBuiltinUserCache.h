//
//  ClientStatsDatabase.h
//  E-Mission
//
//  Created by Kalyanaraman Shankari on 9/18/14.
//  Copyright (c) 2014 Kalyanaraman Shankari. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <sqlite3.h>
#import "TimeQuery.h"

#define CLIENT_STATS_DB_NIL_VALUE @"none"

@interface BuiltinUserCache : NSObject {
    sqlite3 *_database;
}

+ (BuiltinUserCache*) database;
+ (double) getCurrentTimeSecs;
+ (NSString*) getCurrentTimeSecsString;

-(NSDictionary*)createSensorData:key write_ts:(NSDate*)write_ts timezone:(NSString*)tz data:(NSObject*)data;
-(NSString*) getStatName:(NSString*)plistKey;

// We implement the same interface as the android code, to use somewhat tested code

// Versions that save wrapper classes, for use with native code
- (void) putSensorData:(NSString*) label value:(NSObject*)value;
- (void) putMessage:(NSString*) label value:(NSObject*)value;
- (void)putReadWriteDocument:(NSString*)label value:(NSObject*)value;

// Versions that save JSON directly, for use with the plugin
- (void) putSensorData:(NSString*) label jsonValue:(NSDictionary*)value;
- (void) putMessage:(NSString*) label jsonValue:(NSDictionary*)value;
- (void)putReadWriteDocument:(NSString*)label jsonValue:(NSDictionary*)value;

// Versions that return a particular wrapper class, for use with the native code

- (NSArray*) getSensorDataForInterval:(NSString*) key tq:(TimeQuery*)tq wrapperClass:(Class)cls;
- (NSArray*) getLastSensorData:(NSString*) key nEntries:(int)nEntries wrapperClass:(Class)cls;

- (NSArray*) getMessageForInterval:(NSString*) key tq:(TimeQuery*)tq wrapperClass:(Class)cls;
- (NSArray*) getLastMessage:(NSString*) key nEntries:(int)nEntries wrapperClass:(Class)cls;
- (NSObject*) getDocument:(NSString*)key wrapperClass:(Class)cls;

// Versions that return JSON, for use with the plugin interface

- (NSArray*) getSensorDataForInterval:(NSString*) key tq:(TimeQuery*)tq withMetadata:(BOOL)withMetadata;
- (NSArray*) getLastSensorData:(NSString*) key nEntries:(int)nEntries withMetadata:(BOOL)withMetadata;

- (NSArray*) getMessageForInterval:(NSString*) key tq:(TimeQuery*)tq withMetadata:(BOOL)withMetadata;
- (NSArray*) getLastMessage:(NSString*) key nEntries:(int)nEntries withMetadata:(BOOL)withMetadata;

- (NSDictionary*) getDocument:(NSString*)key withMetadata:(BOOL)withMetadata;

- (double) getTsOfLastTransition;
- (NSArray*) syncPhoneToServer;
- (void) syncServerToPhone:(NSArray*)documentArray;

+ (TimeQuery*) getTimeQuery:(NSArray*)pointList;
+ (NSString*) getTimezone:(NSDictionary*)entry;
+ (NSDate*) getWriteTs:(NSDictionary*)entry;

- (void) clearEntries:(TimeQuery*)tq;
- (void) clearSupersededRWDocs:(TimeQuery*)tq;
- (void) clearObsoleteDocs:(TimeQuery*)tq;
- (void) checkAfterPull;
- (void) invalidateCache:(TimeQuery*)tq;
- (void) clear;
@end
