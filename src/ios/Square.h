#import <Cordova/CDV.h>

@interface Square : CDVPlugin {
}
- (void)setOptions:(CDVInvokedUrlCommand*)command;
- (void)requestCharge:(CDVInvokedUrlCommand*)command;

@end
