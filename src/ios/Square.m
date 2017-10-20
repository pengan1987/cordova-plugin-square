#import "Square.h"
#import <SquarePointOfSaleSDK.h>

@implementation Square

static NSString* const OPT_APPLICATION_ID = @"applicationId";
static NSString* const OPT_AMOUNT = @"amount";
static NSString* const OPT_CURRENCY = @"currency";
static NSString* const OPT_TENDERS = @"tenders";
static NSString* const OPT_LOCATION_ID = @"locationId";
static NSString* const OPT_TIMEOUT = @"timeout";
static NSString* const OPT_NOTE = @"note";
static NSString* const OPT_METADATA = @"metadata";

NSString* callbackUrlString_;
NSString* applicationId_;
NSString* currency_;
SCCAPIRequestTenderTypes tenders_ = SCCAPIRequestTenderTypeCard;
NSString* locationId_;
int timeout_;
NSString* note_;
NSString* metadata_;
NSString* callbackId_;

/** Option Defaults */
static NSString* const DEFAULT_CURRENCY = @"USD";
const int DEFAULT_TIMEOUT = 3500;

- (void)setOptions:(CDVInvokedUrlCommand*)command
{
    NSString* customizedSchema = [[[[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleURLTypes"] objectAtIndex:0] objectForKey:@"CFBundleURLSchemes"] objectAtIndex:0];
    callbackUrlString_ = [customizedSchema stringByAppendingString:@"://squarepay"];
    NSArray* options = [command.arguments objectAtIndex:0];
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    if ([options valueForKey:OPT_APPLICATION_ID]) {
        applicationId_ = [options valueForKey:OPT_APPLICATION_ID];
        NSLog(@"Application ID: %@", applicationId_);
    }
    if ([options valueForKey:OPT_CURRENCY])
        currency_ = [options valueForKey:OPT_CURRENCY];

    NSArray* tendersInString = [[NSArray alloc] init];
    if ([options valueForKey:OPT_TENDERS])
        tendersInString = [options valueForKey:OPT_TENDERS];

    //TODO: finish tender selection

    if ([options valueForKey:OPT_LOCATION_ID])
        locationId_ = [options valueForKey:OPT_LOCATION_ID];

    if ([options valueForKey:OPT_TIMEOUT]) {
        timeout_ = [[options valueForKey:OPT_TIMEOUT] intValue];
    } else {
        timeout_ = DEFAULT_TIMEOUT;
    }
    if ([options valueForKey:OPT_METADATA])
        metadata_ = [options valueForKey:OPT_METADATA];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (void)requestCharge:(CDVInvokedUrlCommand*)command
{
    NSArray* options = [command.arguments objectAtIndex:0];
    CDVPluginResult* result = nil;

    int amount = 0;
    if (![options valueForKey:OPT_AMOUNT]) {
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Amount can't be null"];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        return;
    }
    amount = [[options valueForKey:OPT_AMOUNT] intValue];

    NSError* error = nil;
    SCCMoney* sccAmount = [SCCMoney moneyWithAmountCents:amount currencyCode:currency_ error:&error];
    if (error) {
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Invalid Amount"];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        return;
    }

    [SCCAPIRequest setClientID:applicationId_];
    SCCAPIRequest* request = [SCCAPIRequest requestWithCallbackURL:[NSURL URLWithString:callbackUrlString_]
                                                            amount:sccAmount
                                                    userInfoString:nil
                                                        locationID:locationId_
                                                             notes:note_
                                                        customerID:nil
                                              supportedTenderTypes:tenders_
                                                 clearsDefaultFees:NO
                                   returnAutomaticallyAfterPayment:YES
                                                             error:&error];

    if (error) {
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Invalid Request"];
        NSLog(@"Error: %@", [error localizedDescription]);
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        return;
    }

    if (![SCCAPIConnection performRequest:request error:&error]) {
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Cannot Perform Request"];
        NSLog(@"Error: %@", [error localizedDescription]);
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        return;
    }
    callbackId_ = command.callbackId;
}

- (void)handleOpenURL:(NSNotification*)notification
{
    CDVPluginResult* result = nil;
    NSURL* url = [notification object];
    if ([url isKindOfClass:[NSURL class]]) {
        NSError* decodeError;
        SCCAPIResponse* const response = [SCCAPIResponse responseWithResponseURL:url error:&decodeError];
        NSLog(@"trying open url: %@", [url absoluteString]);
        if ([response isSuccessResponse]) {
            NSDictionary* successMessage = [NSDictionary dictionaryWithObjectsAndKeys:[response transactionID], @"serverTransactionId", [response clientTransactionID], @"clientTransactionId", nil];
            result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:successMessage];
        } else {
            NSString* errorMessage = [response.error localizedDescription];
            result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errorMessage];
        }
        [self.commandDelegate sendPluginResult:result callbackId:callbackId_];
    }
}
@end
