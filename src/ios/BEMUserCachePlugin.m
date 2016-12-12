#import "BEMUserCachePlugin.h"
#import "BEMBuiltinUserCache.h"
#import "DataUtils.h"

@implementation BEMUserCachePlugin

- (void)pluginInitialize
{
    // TODO: We should consider adding a create statement to the init, similar
    // to android - then it doesn't matter if the pre-populated database is not
    // copied over.
    NSLog(@"BEMUserCache:pluginInitialize singleton -> initialize native DB");
    NSLog(@"Database is %@", [BuiltinUserCache database]);
}

- (void) getDocument:(CDVInvokedUrlCommand*)command
{
    NSString* callbackId = [command callbackId];
    @try {
        NSString* key = [[command arguments] objectAtIndex:0];
        BOOL withMetadata = [[[command arguments] objectAtIndex:1] boolValue];
        NSDictionary* resultDoc = [[BuiltinUserCache database] getDocument:key
                                                              withMetadata:withMetadata];
        if (resultDoc == NULL) {
            resultDoc = [NSDictionary new];
        }
        CDVPluginResult* result = [CDVPluginResult
                                   resultWithStatus:CDVCommandStatus_OK
                                   messageAsDictionary:resultDoc];
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    }
    @catch (NSException *exception) {
        NSString* msg = [NSString stringWithFormat: @"While getting document, error %@", exception];
        CDVPluginResult* result = [CDVPluginResult
                                       resultWithStatus:CDVCommandStatus_ERROR
                                       messageAsString:msg];
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    }
}

- (void) getSensorDataForInterval:(CDVInvokedUrlCommand*)command
{
    NSString* callbackId = [command callbackId];
    @try {
        NSString* key = [[command arguments] objectAtIndex:0];
        NSDictionary* timequeryDoc = [command.arguments objectAtIndex:1];
        TimeQuery* timequery = [TimeQuery new];
        [DataUtils dictToWrapper:timequeryDoc wrapper:timequery];
        BOOL withMetadata = [[[command arguments] objectAtIndex:2] boolValue];
        NSArray* resultDoc = [[BuiltinUserCache database] getSensorDataForInterval:key
                                                                                tq:timequery
                                                                      withMetadata:withMetadata];
        CDVPluginResult* result = [CDVPluginResult
                                   resultWithStatus:CDVCommandStatus_OK
                                   messageAsArray:resultDoc];
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    }
    @catch (NSException *exception) {
        NSString* msg = [NSString stringWithFormat: @"While getting sensor data, error %@", exception];
        CDVPluginResult* result = [CDVPluginResult
                                   resultWithStatus:CDVCommandStatus_ERROR
                                   messageAsString:msg];
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    }
}

- (void) getMessagesForInterval:(CDVInvokedUrlCommand*)command
{
    NSString* callbackId = [command callbackId];
    @try {
        NSString* key = [[command arguments] objectAtIndex:0];
        NSDictionary* timequeryDoc = [command.arguments objectAtIndex:1];
        TimeQuery* timequery = [TimeQuery new];
        [DataUtils dictToWrapper:timequeryDoc wrapper:timequery];
        BOOL withMetadata = [[[command arguments] objectAtIndex:2] boolValue];
        NSArray* resultDoc = [[BuiltinUserCache database] getMessageForInterval:key
                                                                             tq:timequery
                                                                   withMetadata:withMetadata];
        CDVPluginResult* result = [CDVPluginResult
                                   resultWithStatus:CDVCommandStatus_OK
                                   messageAsArray:resultDoc];
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    }
    @catch (NSException *exception) {
        NSString* msg = [NSString stringWithFormat: @"While getting messages, error %@", exception];
        CDVPluginResult* result = [CDVPluginResult
                                   resultWithStatus:CDVCommandStatus_ERROR
                                   messageAsString:msg];
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    }
    
}

- (void) getLastMessages:(CDVInvokedUrlCommand*)command
{
    NSString* callbackId = [command callbackId];
    @try {
        NSString* key = [[command arguments] objectAtIndex:0];
        NSString* nEntriesStr = [command.arguments objectAtIndex:1];
        int nEntries = [nEntriesStr intValue];
        BOOL withMetadata = [[[command arguments] objectAtIndex:2] boolValue];
        NSArray* resultDoc = [[BuiltinUserCache database] getLastMessage:key
                                                                nEntries:nEntries
                                                                   withMetadata:withMetadata];
        CDVPluginResult* result = [CDVPluginResult
                                   resultWithStatus:CDVCommandStatus_OK
                                   messageAsArray:resultDoc];
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    }
    @catch (NSException *exception) {
        NSString* msg = [NSString stringWithFormat: @"While get last messages, error %@", exception];
        CDVPluginResult* result = [CDVPluginResult
                                   resultWithStatus:CDVCommandStatus_ERROR
                                   messageAsString:msg];
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    }
}

- (void) getLastSensorData:(CDVInvokedUrlCommand *)command
{
    NSString* callbackId = [command callbackId];
    @try {
        NSString* key = [[command arguments] objectAtIndex:0];
        NSString* nEntriesStr = [command.arguments objectAtIndex:1];
        int nEntries = [nEntriesStr intValue];
        BOOL withMetadata = [[[command arguments] objectAtIndex:2] boolValue];
        NSArray* resultDoc = [[BuiltinUserCache database] getLastMessage:key
                                                                nEntries:nEntries
                                                            withMetadata:withMetadata];
        CDVPluginResult* result = [CDVPluginResult
                                   resultWithStatus:CDVCommandStatus_OK
                                   messageAsArray:resultDoc];
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    }
    @catch (NSException *exception) {
        NSString* msg = [NSString stringWithFormat: @"While getting last messages, error %@", exception];
        CDVPluginResult* result = [CDVPluginResult
                                   resultWithStatus:CDVCommandStatus_ERROR
                                   messageAsString:msg];
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    }
}

- (void) putMessage:(CDVInvokedUrlCommand *)command
{
    NSString* callbackId = [command callbackId];
    @try {
        NSString* key = [[command arguments] objectAtIndex:0];
        NSDictionary* value = [command.arguments objectAtIndex:1];

        [[BuiltinUserCache database] putMessage:key jsonValue:value];
        CDVPluginResult* result = [CDVPluginResult
                                   resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    }
    @catch (NSException *exception) {
        NSString* msg = [NSString stringWithFormat: @"While putting message, error %@", exception];
        CDVPluginResult* result = [CDVPluginResult
                                   resultWithStatus:CDVCommandStatus_ERROR
                                   messageAsString:msg];
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    }
}

- (void) putRWDocument:(CDVInvokedUrlCommand *)command
{
    NSString* callbackId = [command callbackId];
    @try {
        NSString* key = [[command arguments] objectAtIndex:0];
        NSDictionary* value = [command.arguments objectAtIndex:1];
        
        [[BuiltinUserCache database] putReadWriteDocument:key jsonValue:value];
        CDVPluginResult* result = [CDVPluginResult
                                   resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    }
    @catch (NSException *exception) {
        NSString* msg = [NSString stringWithFormat: @"While putting RW document, error %@", exception];
        CDVPluginResult* result = [CDVPluginResult
                                   resultWithStatus:CDVCommandStatus_ERROR
                                   messageAsString:msg];
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    }
}

- (void) putSensorData:(CDVInvokedUrlCommand *)command
{
    NSString* callbackId = [command callbackId];
    @try {
        NSString* key = [[command arguments] objectAtIndex:0];
        NSDictionary* value = [command.arguments objectAtIndex:1];

        [[BuiltinUserCache database] putSensorData:key jsonValue:value];
        CDVPluginResult* result = [CDVPluginResult
                                   resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    }
    @catch (NSException *exception) {
        NSString* msg = [NSString stringWithFormat: @"While putting sensor data, error %@", exception];
        CDVPluginResult* result = [CDVPluginResult
                                   resultWithStatus:CDVCommandStatus_ERROR
                                   messageAsString:msg];
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    }
}

- (void) putLocalStorage:(CDVInvokedUrlCommand *)command
{
    NSString* callbackId = [command callbackId];
    @try {
        NSString* key = [[command arguments] objectAtIndex:0];
        NSDictionary* value = [command.arguments objectAtIndex:1];
        
        [[BuiltinUserCache database] putLocalStorage:key jsonValue:value];
        CDVPluginResult* result = [CDVPluginResult
                                   resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    }
    @catch (NSException *exception) {
        NSString* msg = [NSString stringWithFormat: @"While putting sensor data, error %@", exception];
        CDVPluginResult* result = [CDVPluginResult
                                   resultWithStatus:CDVCommandStatus_ERROR
                                   messageAsString:msg];
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    }
}

- (void) getLocalStorage:(CDVInvokedUrlCommand*)command
{
    NSString* callbackId = [command callbackId];
    @try {
        NSString* key = [[command arguments] objectAtIndex:0];
        BOOL withMetadata = [[[command arguments] objectAtIndex:1] boolValue];
        NSDictionary* resultDoc = [[BuiltinUserCache database] getLocalStorage:key
                                                             withMetadata:withMetadata];
        CDVPluginResult* result = [CDVPluginResult
                                   resultWithStatus:CDVCommandStatus_OK
                                   messageAsDictionary:resultDoc];
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    }
    @catch (NSException *exception) {
        NSString* msg = [NSString stringWithFormat: @"While getting messages, error %@", exception];
        CDVPluginResult* result = [CDVPluginResult
                                   resultWithStatus:CDVCommandStatus_ERROR
                                   messageAsString:msg];
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    }
    
}

- (void) removeLocalStorage:(CDVInvokedUrlCommand*)command
{
    NSString* callbackId = [command callbackId];
    @try {
        NSString* key = [[command arguments] objectAtIndex:0];
        [[BuiltinUserCache database] removeLocalStorage:key];
        CDVPluginResult* result = [CDVPluginResult
                                   resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    }
    @catch (NSException *exception) {
        NSString* msg = [NSString stringWithFormat: @"While getting messages, error %@", exception];
        CDVPluginResult* result = [CDVPluginResult
                                   resultWithStatus:CDVCommandStatus_ERROR
                                   messageAsString:msg];
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    }

}

- (void) clearEntries:(CDVInvokedUrlCommand *)command
{
    NSString* callbackId = [command callbackId];
    @try {
        NSDictionary* timequeryDoc = [command.arguments objectAtIndex:0];
        TimeQuery* timequery = [TimeQuery new];
        [DataUtils dictToWrapper:timequeryDoc wrapper:timequery];
        // Clearing is now split up, but let's not bloat up the
        // interface further. It is unclear when this will be
        // ever called from the UI anyway, but let us just clear
        // all three types of messages from the phone anyway
        [[BuiltinUserCache database] clearEntries:timequery];
        [[BuiltinUserCache database] clearSupersededRWDocs:timequery];
        [[BuiltinUserCache database] clearObsoleteDocs:timequery];
        CDVPluginResult* result = [CDVPluginResult
                                   resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    }
    @catch (NSException *exception) {
        NSString* msg = [NSString stringWithFormat: @"While getting sensor data, error %@", exception];
        CDVPluginResult* result = [CDVPluginResult
                                   resultWithStatus:CDVCommandStatus_ERROR
                                   messageAsString:msg];
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    }
}

- (void) invalidateCache:(CDVInvokedUrlCommand *)command
{
    NSString* callbackId = [command callbackId];
    @try {
        NSDictionary* timequeryDoc = [command.arguments objectAtIndex:0];
        NSLog(@"timequeryDoc = %@", timequeryDoc);
        TimeQuery* timequery = [TimeQuery new];
        [DataUtils dictToWrapper:timequeryDoc wrapper:timequery];
        [[BuiltinUserCache database] invalidateCache:timequery];
        CDVPluginResult* result = [CDVPluginResult
                                   resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    }
    @catch (NSException *exception) {
        NSString* msg = [NSString stringWithFormat: @"While getting sensor data, error %@", exception];
        CDVPluginResult* result = [CDVPluginResult
                                   resultWithStatus:CDVCommandStatus_ERROR
                                   messageAsString:msg];
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    }
}

- (void) clearAll:(CDVInvokedUrlCommand *)command
{
    NSString* callbackId = [command callbackId];
    @try {
        [[BuiltinUserCache database] clear];
        CDVPluginResult* result = [CDVPluginResult
                                   resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    }
    @catch (NSException *exception) {
        NSString* msg = [NSString stringWithFormat: @"While getting sensor data, error %@", exception];
        CDVPluginResult* result = [CDVPluginResult
                                   resultWithStatus:CDVCommandStatus_ERROR
                                   messageAsString:msg];
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    }
}


@end
