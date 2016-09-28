#import <Cordova/CDV.h>

@interface BEMUserCachePlugin: CDVPlugin

- (void) pluginInitialize;

- (void) getDocument:(CDVInvokedUrlCommand*)command;
- (void) getSensorDataForInterval:(CDVInvokedUrlCommand*)command;
- (void) getMessagesForInterval:(CDVInvokedUrlCommand*)command;
- (void) getLastMessages:(CDVInvokedUrlCommand*)command;
- (void) getLastSensorData:(CDVInvokedUrlCommand *)command;
- (void) putMessage:(CDVInvokedUrlCommand *)command;
- (void) putRWDocument:(CDVInvokedUrlCommand *)command;
- (void) putSensorData:(CDVInvokedUrlCommand *)command;
- (void) clearEntries:(CDVInvokedUrlCommand *)command;
- (void) invalidateCache:(CDVInvokedUrlCommand *)command;
- (void) clearAll:(CDVInvokedUrlCommand *)command;

@end
