#import "BEMUserCachePlugin.h"
#import "BEMBuiltinUserCache.h"

@implementation BEMUserCachePlugin

- (void)pluginInitialize
{
    // TODO: We should consider adding a create statement to the init, similar
    // to android - then it doesn't matter if the pre-populated database is not
    // copied over.
    NSLog(@"BEMUserCache:pluginInitialize singleton -> initialize native DB");
    NSLog(@"Database is %@", [BuiltinUserCache database]);
}

@end
