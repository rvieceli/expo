#import "ABI17_0_0RNBranch.h"
#import <ReactABI17_0_0/ABI17_0_0RCTBridge.h>
#import <ReactABI17_0_0/ABI17_0_0RCTEventDispatcher.h>
#import <ReactABI17_0_0/ABI17_0_0RCTLog.h>
#import "ABI17_0_0BranchLinkProperties+RNBranch.h"
#import "ABI17_0_0BranchUniversalObject+RNBranch.h"
#import "ABI17_0_0RNBranchAgingDictionary.h"
#import "ABI17_0_0RNBranchEventEmitter.h"

NSString * const ABI17_0_0RNBranchLinkOpenedNotification = @"ABI17_0_0RNBranchLinkOpenedNotification";
NSString * const ABI17_0_0RNBranchLinkOpenedNotificationErrorKey = @"error";
NSString * const ABI17_0_0RNBranchLinkOpenedNotificationParamsKey = @"params";
NSString * const ABI17_0_0RNBranchLinkOpenedNotificationUriKey = @"uri";
NSString * const ABI17_0_0RNBranchLinkOpenedNotificationBranchUniversalObjectKey = @"branch_universal_object";
NSString * const ABI17_0_0RNBranchLinkOpenedNotificationLinkPropertiesKey = @"link_properties";

static NSDictionary *initSessionWithLaunchOptionsResult;
static NSURL *sourceUrl;
static Branch *branchInstance;

static NSString * const IdentFieldName = @"ident";

// These are only really exposed to the JS layer, so keep them internal for now.
static NSString * const ABI17_0_0RNBranchErrorDomain = @"ABI17_0_0RNBranchErrorDomain";
static NSInteger const ABI17_0_0RNBranchUniversalObjectNotFoundError = 1;

#pragma mark - Private ABI17_0_0RNBranch declarations

@interface ABI17_0_0RNBranch()
@property (nonatomic, readonly) UIViewController *currentViewController;
@property (nonatomic) ABI17_0_0RNBranchAgingDictionary<NSString *, BranchUniversalObject *> *universalObjectMap;
@end

#pragma mark - ABI17_0_0RNBranch implementation

@implementation ABI17_0_0RNBranch

@synthesize bridge = _bridge;

ABI17_0_0RCT_EXPORT_MODULE();

- (NSDictionary<NSString *, NSString *> *)constantsToExport {
    return @{
             // ABI17_0_0RN events transmitted to JS by event emitter
             @"INIT_SESSION_SUCCESS": ABI17_0_0RNBranchInitSessionSuccess,
             @"INIT_SESSION_ERROR": ABI17_0_0RNBranchInitSessionError,

             // constants for use with userCompletedAction
             @"ADD_TO_CART_EVENT": BNCAddToCartEvent,
             @"ADD_TO_WISHLIST_EVENT": BNCAddToWishlistEvent,
             @"PURCHASED_EVENT": BNCPurchasedEvent,
             @"PURCHASE_INITIATED_EVENT": BNCPurchaseInitiatedEvent,
             @"REGISTER_VIEW_EVENT": BNCRegisterViewEvent,
             @"SHARE_COMPLETED_EVENT": BNCShareCompletedEvent,
             @"SHARE_INITIATED_EVENT": BNCShareInitiatedEvent
             };
}

#pragma mark - Class methods

+ (void)useTestInstance {
    branchInstance = [Branch getTestInstance];
}

//Called by AppDelegate.m -- stores initSession result in static variables and raises initSessionFinished event that's captured by the ABI17_0_0RNBranch instance to emit it to ReactABI17_0_0 Native
+ (void)initSessionWithLaunchOptions:(NSDictionary *)launchOptions isReferrable:(BOOL)isReferrable {
    sourceUrl = launchOptions[UIApplicationLaunchOptionsURLKey];

    if (!branchInstance) {
        branchInstance = [Branch getInstance];
    }
    [branchInstance initSessionWithLaunchOptions:launchOptions isReferrable:isReferrable andRegisterDeepLinkHandler:^(NSDictionary *params, NSError *error) {
        NSMutableDictionary *result = [NSMutableDictionary dictionary];
        if (error) result[ABI17_0_0RNBranchLinkOpenedNotificationErrorKey] = error;
        if (params) {
            result[ABI17_0_0RNBranchLinkOpenedNotificationParamsKey] = params;

            if (params[@"~id"]) {
                BranchUniversalObject *branchUniversalObject = [BranchUniversalObject getBranchUniversalObjectFromDictionary:params];
                if (branchUniversalObject) result[ABI17_0_0RNBranchLinkOpenedNotificationBranchUniversalObjectKey] = branchUniversalObject;

                BranchLinkProperties *linkProperties = [BranchLinkProperties getBranchLinkPropertiesFromDictionary:params];
                if (linkProperties) result[ABI17_0_0RNBranchLinkOpenedNotificationLinkPropertiesKey] = linkProperties;
            }
        }
        if (sourceUrl) result[ABI17_0_0RNBranchLinkOpenedNotificationUriKey] = sourceUrl;

        [[NSNotificationCenter defaultCenter] postNotificationName:ABI17_0_0RNBranchLinkOpenedNotification object:nil userInfo:result];
    }];
}

+ (BOOL)handleDeepLink:(NSURL *)url {
    sourceUrl = url;
    BOOL handled = [branchInstance handleDeepLink:url];
    return handled;
}

+ (BOOL)continueUserActivity:(NSUserActivity *)userActivity {
    sourceUrl = userActivity.webpageURL;
    return [branchInstance continueUserActivity:userActivity];
}

#pragma mark - Object lifecycle

- (instancetype)init {
    self = [super init];

    if (self) {
        // Added to work on Expo, should try to upstream.
        if (!branchInstance) {
            branchInstance = [Branch getInstance];
        }

        _universalObjectMap = [ABI17_0_0RNBranchAgingDictionary dictionaryWithTtl:3600.0];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onInitSessionFinished:) name:ABI17_0_0RNBranchLinkOpenedNotification object:nil];
    }

    return self;
}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Utility methods

- (UIViewController *)currentViewController
{
    UIViewController *current = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (current.presentedViewController && ![current.presentedViewController isKindOfClass:UIAlertController.class]) {
        current = current.presentedViewController;
    }
    return current;
}

- (void) onInitSessionFinished:(NSNotification*) notification {
    NSURL *uri = notification.userInfo[ABI17_0_0RNBranchLinkOpenedNotificationUriKey];
    NSError *error = notification.userInfo[ABI17_0_0RNBranchLinkOpenedNotificationErrorKey];
    NSDictionary *params = notification.userInfo[ABI17_0_0RNBranchLinkOpenedNotificationParamsKey];

    initSessionWithLaunchOptionsResult = @{
                                         ABI17_0_0RNBranchLinkOpenedNotificationErrorKey: error.localizedDescription ?: NSNull.null,
                                         ABI17_0_0RNBranchLinkOpenedNotificationParamsKey: params[@"~id"] ? params : NSNull.null,
                                         ABI17_0_0RNBranchLinkOpenedNotificationUriKey: uri.absoluteString ?: NSNull.null
                                         };

    // If there is an error, fire error event
    if (error) {
        [ABI17_0_0RNBranchEventEmitter initSessionDidEncounterErrorWithPayload:initSessionWithLaunchOptionsResult];
    }

    // otherwise notify the session is finished
    else {
        [ABI17_0_0RNBranchEventEmitter initSessionDidSucceedWithPayload:initSessionWithLaunchOptionsResult];
    }
}

- (BranchLinkProperties*) createLinkProperties:(NSDictionary *)linkPropertiesMap withControlParams:(NSDictionary *)controlParamsMap
{
    BranchLinkProperties *linkProperties = [[BranchLinkProperties alloc] initWithMap:linkPropertiesMap];

    linkProperties.controlParams = controlParamsMap;
    return linkProperties;
}

- (BranchUniversalObject *)findUniversalObjectWithIdent:(NSString *)ident rejecter:(ABI17_0_0RCTPromiseRejectBlock)reject
{
    BranchUniversalObject *universalObject = self.universalObjectMap[ident];

    if (!universalObject) {
        NSString *errorMessage = [NSString stringWithFormat:@"BranchUniversalObject for ident %@ not found.", ident];

        NSError *error = [NSError errorWithDomain:ABI17_0_0RNBranchErrorDomain
                                             code:ABI17_0_0RNBranchUniversalObjectNotFoundError
                                         userInfo:@{IdentFieldName : ident,
                                                    NSLocalizedDescriptionKey: errorMessage
                                                    }];
        
        reject(@"ABI17_0_0RNBranch::Error::BUONotFound", errorMessage, error);
    }
    
    return universalObject;
}

#pragma mark - Methods exported to ReactABI17_0_0 Native

#pragma mark redeemInitSessionResult
ABI17_0_0RCT_EXPORT_METHOD(
                  redeemInitSessionResult:(ABI17_0_0RCTPromiseResolveBlock)resolve
                  rejecter:(__unused ABI17_0_0RCTPromiseRejectBlock)reject
                  ) {
    resolve(initSessionWithLaunchOptionsResult ? initSessionWithLaunchOptionsResult : [NSNull null]);
}

#pragma mark setDebug
ABI17_0_0RCT_EXPORT_METHOD(
                  setDebug
                  ) {
    [branchInstance setDebug];
}

#pragma mark getLatestReferringParams
ABI17_0_0RCT_EXPORT_METHOD(
                  getLatestReferringParams:(ABI17_0_0RCTPromiseResolveBlock)resolve
                  rejecter:(__unused ABI17_0_0RCTPromiseRejectBlock)reject
                  ) {
    resolve([branchInstance getLatestReferringParams]);
}

#pragma mark getFirstReferringParams
ABI17_0_0RCT_EXPORT_METHOD(
                  getFirstReferringParams:(ABI17_0_0RCTPromiseResolveBlock)resolve
                  rejecter:(__unused ABI17_0_0RCTPromiseRejectBlock)reject
                  ) {
    resolve([branchInstance getFirstReferringParams]);
}

#pragma mark setIdentity
ABI17_0_0RCT_EXPORT_METHOD(
                  setIdentity:(NSString *)identity
                  ) {
    [branchInstance setIdentity:identity];
}

#pragma mark logout
ABI17_0_0RCT_EXPORT_METHOD(
                  logout
                  ) {
    [branchInstance logout];
}

#pragma mark userCompletedAction
ABI17_0_0RCT_EXPORT_METHOD(
                  userCompletedAction:(NSString *)event withState:(NSDictionary *)appState
                  ) {
    [branchInstance userCompletedAction:event withState:appState];
}

#pragma mark userCompletedActionOnUniversalObject
ABI17_0_0RCT_EXPORT_METHOD(
                  userCompletedActionOnUniversalObject:(NSString *)identifier
                  event:(NSString *)event
                  resolver:(ABI17_0_0RCTPromiseResolveBlock)resolve
                  rejecter:(ABI17_0_0RCTPromiseRejectBlock)reject
) {
    BranchUniversalObject *branchUniversalObject = [self findUniversalObjectWithIdent:identifier rejecter:reject];
    if (!branchUniversalObject) return;

    [branchUniversalObject userCompletedAction:event];
    resolve(NSNull.null);
}

#pragma mark userCompletedActionOnUniversalObject
ABI17_0_0RCT_EXPORT_METHOD(
                  userCompletedActionOnUniversalObject:(NSString *)identifier
                  event:(NSString *)event
                  state:(NSDictionary *)state
                  resolver:(ABI17_0_0RCTPromiseResolveBlock)resolve
                  rejecter:(ABI17_0_0RCTPromiseRejectBlock)reject
                  ) {
    BranchUniversalObject *branchUniversalObject = [self findUniversalObjectWithIdent:identifier rejecter:reject];
    if (!branchUniversalObject) return;

    [branchUniversalObject userCompletedAction:event withState:state];
    resolve(NSNull.null);
}

#pragma mark showShareSheet
ABI17_0_0RCT_EXPORT_METHOD(
                  showShareSheet:(NSString *)identifier
                  withShareOptions:(NSDictionary *)shareOptionsMap
                  withLinkProperties:(NSDictionary *)linkPropertiesMap
                  withControlParams:(NSDictionary *)controlParamsMap
                  resolver:(ABI17_0_0RCTPromiseResolveBlock)resolve
                  rejecter:(ABI17_0_0RCTPromiseRejectBlock)reject
                  ) {
    BranchUniversalObject *branchUniversalObject = [self findUniversalObjectWithIdent:identifier rejecter:reject];
    if (!branchUniversalObject) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        NSMutableDictionary *mutableControlParams = controlParamsMap.mutableCopy;
        if (shareOptionsMap && shareOptionsMap[@"emailSubject"]) {
            mutableControlParams[@"$email_subject"] = shareOptionsMap[@"emailSubject"];
        }

        BranchLinkProperties *linkProperties = [self createLinkProperties:linkPropertiesMap withControlParams:mutableControlParams];

        [branchUniversalObject showShareSheetWithLinkProperties:linkProperties
                                                   andShareText:shareOptionsMap[@"messageBody"]
                                             fromViewController:self.currentViewController
                                            completionWithError:^(NSString * _Nullable activityType, BOOL completed, NSError * _Nullable activityError){
                                                if (activityError) {
                                                    NSString *errorCodeString = [NSString stringWithFormat:@"%ld", (long)activityError.code];
                                                    reject(errorCodeString, activityError.localizedDescription, activityError);
                                                    return;
                                                }

                                                NSDictionary *result = @{
                                                                         @"channel" : activityType ?: [NSNull null],
                                                                         @"completed" : @(completed),
                                                                         @"error" : [NSNull null]
                                                                         };

                                                resolve(result);
                                            }];
    });
}

#pragma mark registerView
ABI17_0_0RCT_EXPORT_METHOD(
                  registerView:(NSString *)identifier
                  resolver:(ABI17_0_0RCTPromiseResolveBlock)resolve
                  rejecter:(ABI17_0_0RCTPromiseRejectBlock)reject
                  ) {
    BranchUniversalObject *branchUniversalObject = [self findUniversalObjectWithIdent:identifier rejecter:reject];
    if (!branchUniversalObject) return;

    [branchUniversalObject registerViewWithCallback:^(NSDictionary *params, NSError *error) {
        if (!error) {
            resolve([NSNull null]);
        } else {
            reject([NSString stringWithFormat: @"%lu", (long)error.code], error.localizedDescription, error);
        }
    }];
}

#pragma mark generateShortUrl
ABI17_0_0RCT_EXPORT_METHOD(
                  generateShortUrl:(NSString *)identifier
                  withLinkProperties:(NSDictionary *)linkPropertiesMap
                  withControlParams:(NSDictionary *)controlParamsMap
                  resolver:(ABI17_0_0RCTPromiseResolveBlock)resolve
                  rejecter:(ABI17_0_0RCTPromiseRejectBlock)reject
                  ) {
    BranchUniversalObject *branchUniversalObject = [self findUniversalObjectWithIdent:identifier rejecter:reject];
    if (!branchUniversalObject) return;

    BranchLinkProperties *linkProperties = [self createLinkProperties:linkPropertiesMap withControlParams:controlParamsMap];

    [branchUniversalObject getShortUrlWithLinkProperties:linkProperties andCallback:^(NSString *url, NSError *error) {
        if (!error) {
            ABI17_0_0RCTLogInfo(@"ABI17_0_0RNBranch Success");
            resolve(@{ @"url": url });
        } else {
            reject([NSString stringWithFormat: @"%lu", (long)error.code], error.localizedDescription, error);
        }
    }];
}

#pragma mark listOnSpotlight
ABI17_0_0RCT_EXPORT_METHOD(
                  listOnSpotlight:(NSString *)identifier
                  resolver:(ABI17_0_0RCTPromiseResolveBlock)resolve
                  rejecter:(ABI17_0_0RCTPromiseRejectBlock)reject
                  ) {
    BranchUniversalObject *branchUniversalObject = [self findUniversalObjectWithIdent:identifier rejecter:reject];
    if (!branchUniversalObject) return;

    [branchUniversalObject listOnSpotlightWithCallback:^(NSString *string, NSError *error) {
        if (!error) {
            NSDictionary *data = @{@"result":string};
            resolve(data);
        } else {
            reject([NSString stringWithFormat: @"%lu", (long)error.code], error.localizedDescription, error);
        }
    }];
}

// @TODO can this be removed? legacy, short url should be created from BranchUniversalObject
#pragma mark getShortUrl
ABI17_0_0RCT_EXPORT_METHOD(
                  getShortUrl:(NSDictionary *)linkPropertiesMap
                  resolver:(ABI17_0_0RCTPromiseResolveBlock)resolve
                  rejecter:(ABI17_0_0RCTPromiseRejectBlock)reject
                  ) {
    NSString *feature = linkPropertiesMap[@"feature"];
    NSString *channel = linkPropertiesMap[@"channel"];
    NSString *stage = linkPropertiesMap[@"stage"];
    NSArray *tags = linkPropertiesMap[@"tags"];

    [branchInstance getShortURLWithParams:linkPropertiesMap
                                  andTags:tags
                               andChannel:channel
                               andFeature:feature
                                 andStage:stage
                              andCallback:^(NSString *url, NSError *error) {
                                  if (error) {
                                      ABI17_0_0RCTLogError(@"ABI17_0_0RNBranch::Error: %@", error.localizedDescription);
                                      reject(@"ABI17_0_0RNBranch::Error", @"getShortURLWithParams", error);
                                  }
                                  resolve(url);
                              }];
}

#pragma mark loadRewards
ABI17_0_0RCT_EXPORT_METHOD(
                  loadRewards:(ABI17_0_0RCTPromiseResolveBlock)resolve
                  rejecter:(ABI17_0_0RCTPromiseRejectBlock)reject
                  ) {
    [branchInstance loadRewardsWithCallback:^(BOOL changed, NSError *error) {
        if(!error) {
            int credits = (int)[branchInstance getCredits];
            resolve(@{@"credits": @(credits)});
        } else {
            ABI17_0_0RCTLogError(@"Load Rewards Error: %@", error.localizedDescription);
            reject(@"ABI17_0_0RNBranch::Error::loadRewardsWithCallback", @"loadRewardsWithCallback", error);
        }
    }];
}

#pragma mark redeemRewards
ABI17_0_0RCT_EXPORT_METHOD(
                  redeemRewards:(NSInteger)amount
                  inBucket:(NSString *)bucket
                  resolver:(ABI17_0_0RCTPromiseResolveBlock)resolve
                  rejecter:(ABI17_0_0RCTPromiseRejectBlock)reject
                  ) {
    if (bucket) {
        [branchInstance redeemRewards:amount forBucket:bucket callback:^(BOOL changed, NSError *error) {
            if (!error) {
                resolve(@{@"changed": @(changed)});
            } else {
                ABI17_0_0RCTLogError(@"Redeem Rewards Error: %@", error.localizedDescription);
                reject(@"ABI17_0_0RNBranch::Error::redeemRewards", error.localizedDescription, error);
            }
        }];
    } else {
        [branchInstance redeemRewards:amount callback:^(BOOL changed, NSError *error) {
            if (!error) {
                resolve(@{@"changed": @(changed)});
            } else {
                ABI17_0_0RCTLogError(@"Redeem Rewards Error: %@", error.localizedDescription);
                reject(@"ABI17_0_0RNBranch::Error::redeemRewards", error.localizedDescription, error);
            }
        }];
    }
}

#pragma mark getCreditHistory
ABI17_0_0RCT_EXPORT_METHOD(
                  getCreditHistory:(ABI17_0_0RCTPromiseResolveBlock)resolve
                  rejecter:(ABI17_0_0RCTPromiseRejectBlock)reject
                  ) {
    [branchInstance getCreditHistoryWithCallback:^(NSArray *list, NSError *error) {
        if (!error) {
            resolve(list);
        } else {
            ABI17_0_0RCTLogError(@"Credit History Error: %@", error.localizedDescription);
            reject(@"ABI17_0_0RNBranch::Error::getCreditHistory", error.localizedDescription, error);
        }
    }];
}

#pragma mark createUniversalObject
ABI17_0_0RCT_EXPORT_METHOD(
                  createUniversalObject:(NSDictionary *)universalObjectProperties
                  resolver:(ABI17_0_0RCTPromiseResolveBlock)resolve
                  rejecter:(__unused ABI17_0_0RCTPromiseRejectBlock)reject
                  ) {
    BranchUniversalObject *universalObject = [[BranchUniversalObject alloc] initWithMap:universalObjectProperties];
    NSString *identifier = [NSUUID UUID].UUIDString;
    self.universalObjectMap[identifier] = universalObject;
    NSDictionary *response = @{IdentFieldName: identifier};

    resolve(response);
}

#pragma mark releaseUniversalObject
ABI17_0_0RCT_EXPORT_METHOD(
                  releaseUniversalObject:(NSString *)identifier
                  ) {
    [self.universalObjectMap removeObjectForKey:identifier];
}

@end
