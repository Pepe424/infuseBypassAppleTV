//
//  InfuseAttackSimulation.mm
//
//  Internal-only active attack simulation for com.firecore.infuse.securitytest.
//  This intentionally reproduces historical result and container tampering so
//  the internal build can validate its runtime defenses end to end.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static NSString *const IASTargetBundleIdentifier = @"com.firecore.infuse.securitytest";

static IMP IASOriginalObjCIAPVersionStatus = NULL;
static IMP IASOriginalSwiftIAPVersionStatus = NULL;
static IMP IASOriginalIsFeaturePurchased = NULL;
static IMP IASOriginalContainerURL = NULL;
static IMP IASOriginalDefaultContainer = NULL;
static IMP IASOriginalContainerWithIdentifier = NULL;

static void IASLog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);

static void IASLog(NSString *format, ...) {
    va_list arguments;
    va_start(arguments, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    NSLog(@"[InfuseAttackSimulation] %@", message);
}
static NSInteger IASForgedObjCIAPVersionStatus(id self, SEL selector) {
    (void)self;
    (void)selector;
    IASLog(@"forged legacy iapVersionStatus -> 1");
    return 1;
}

static NSInteger IASForgedSwiftIAPVersionStatus(id self, SEL selector) {
    (void)self;
    (void)selector;
    IASLog(@"forged StoreKit 2 iapVersionStatus -> 1");
    return 1;
}

static BOOL IASForgedIsFeaturePurchased(id self, SEL selector, NSInteger feature,
                                        id *tillDate) {
    (void)self;
    (void)selector;
    (void)tillDate;
    IASLog(@"forged isFeaturePurchased:%lld -> YES", (long long)feature);
    return YES;
}

static NSURL *IASForgedContainerURL(id self, SEL selector, NSString *groupIdentifier) {
    (void)self;
    (void)selector;

    NSString *basePath = [NSHomeDirectory()
        stringByAppendingPathComponent:@"Documents/ApplicationGroupContainers"];
    NSURL *baseURL = [NSURL fileURLWithPath:basePath isDirectory:YES];
    NSURL *containerURL = [baseURL URLByAppendingPathComponent:groupIdentifier ?: @"nil"];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray<NSString *> *subdirectories = @[
        @"Library/Application Support",
        @"Library/Caches",
        @"Library/Preferences"
    ];

    NSError *error = nil;
    [fileManager createDirectoryAtURL:containerURL
          withIntermediateDirectories:YES
                           attributes:nil
                                error:&error];
    if (error != nil) {
        IASLog(@"failed to create simulated app-group container: %@", error);
        return containerURL;
    }

    for (NSString *subdirectory in subdirectories) {
        NSURL *directoryURL = [containerURL URLByAppendingPathComponent:subdirectory];
        [fileManager createDirectoryAtURL:directoryURL
              withIntermediateDirectories:YES
                               attributes:nil
                                    error:&error];
        if (error != nil) {
            IASLog(@"failed to create %@: %@", subdirectory, error);
            error = nil;
        }
    }

    IASLog(@"redirected app-group %@ -> %@", groupIdentifier ?: @"<nil>",
           containerURL.path);
    return containerURL;
}

static id IASForgedDefaultContainer(id self, SEL selector) {
    (void)self;
    (void)selector;
    IASLog(@"forced CKContainer defaultContainer -> nil");
    return nil;
}

static id IASForgedContainerWithIdentifier(id self, SEL selector, NSString *identifier) {
    (void)self;
    (void)selector;
    IASLog(@"forced CKContainer %@ -> nil", identifier ?: @"<nil>");
    return nil;
}

static void IASInstallInstanceHook(Class targetClass, SEL selector, IMP replacement,
                                   IMP *original) {
    if (targetClass == Nil || *original != NULL) {
        return;
    }

    Method method = class_getInstanceMethod(targetClass, selector);
    if (method == NULL) {
        return;
    }

    *original = method_setImplementation(method, replacement);
    IASLog(@"installed active hook -[%@ %@]", NSStringFromClass(targetClass),
           NSStringFromSelector(selector));
}

static void IASInstallClassHook(Class targetClass, SEL selector, IMP replacement,
                                IMP *original) {
    if (targetClass != Nil) {
        IASInstallInstanceHook(object_getClass(targetClass), selector, replacement, original);
    }
}

static void IASInstallHooks(void) {
    Class objcIAPClass = objc_getClass("FCInAppPurchaseServiceFreemium");
    IASInstallInstanceHook(objcIAPClass, NSSelectorFromString(@"iapVersionStatus"),
                           (IMP)IASForgedObjCIAPVersionStatus,
                           &IASOriginalObjCIAPVersionStatus);

    Class swiftIAPClass = objc_getClass("_TtC6infuse31InAppPurchaseServiceFreemiumSK2");
    IASInstallInstanceHook(swiftIAPClass, NSSelectorFromString(@"iapVersionStatus"),
                           (IMP)IASForgedSwiftIAPVersionStatus,
                           &IASOriginalSwiftIAPVersionStatus);
    IASInstallInstanceHook(swiftIAPClass, NSSelectorFromString(@"isFeaturePurchased:tillDate:"),
                           (IMP)IASForgedIsFeaturePurchased,
                           &IASOriginalIsFeaturePurchased);

    IASInstallInstanceHook([NSFileManager class],
                           @selector(containerURLForSecurityApplicationGroupIdentifier:),
                           (IMP)IASForgedContainerURL, &IASOriginalContainerURL);

    Class cloudKitClass = objc_getClass("CKContainer");
    IASInstallClassHook(cloudKitClass, NSSelectorFromString(@"defaultContainer"),
                        (IMP)IASForgedDefaultContainer, &IASOriginalDefaultContainer);
    IASInstallClassHook(cloudKitClass, NSSelectorFromString(@"containerWithIdentifier:"),
                        (IMP)IASForgedContainerWithIdentifier,
                        &IASOriginalContainerWithIdentifier);
}

static void IASVerifyInstanceHook(Class targetClass, SEL selector, IMP expected,
                                  NSString *name) {
    Method method = targetClass == Nil ? NULL : class_getInstanceMethod(targetClass, selector);
    if (method == NULL) {
        IASLog(@"verification: %@ unavailable", name);
        return;
    }

    IMP current = method_getImplementation(method);
    IASLog(@"verification: %@ %@", name, current == expected ? @"ACTIVE" : @"BLOCKED/REVERTED");
}

static void IASVerifyHooks(void) {
    Class objcIAPClass = objc_getClass("FCInAppPurchaseServiceFreemium");
    IASVerifyInstanceHook(objcIAPClass, NSSelectorFromString(@"iapVersionStatus"),
                          (IMP)IASForgedObjCIAPVersionStatus, @"legacy purchase status");

    Class swiftIAPClass = objc_getClass("_TtC6infuse31InAppPurchaseServiceFreemiumSK2");
    IASVerifyInstanceHook(swiftIAPClass, NSSelectorFromString(@"iapVersionStatus"),
                          (IMP)IASForgedSwiftIAPVersionStatus, @"StoreKit 2 purchase status");
    IASVerifyInstanceHook(swiftIAPClass,
                          NSSelectorFromString(@"isFeaturePurchased:tillDate:"),
                          (IMP)IASForgedIsFeaturePurchased, @"feature purchase check");
    IASVerifyInstanceHook([NSFileManager class],
                          @selector(containerURLForSecurityApplicationGroupIdentifier:),
                          (IMP)IASForgedContainerURL, @"app-group redirect");

    Class cloudKitMetaClass = object_getClass(objc_getClass("CKContainer"));
    IASVerifyInstanceHook(cloudKitMetaClass, NSSelectorFromString(@"defaultContainer"),
                          (IMP)IASForgedDefaultContainer, @"CloudKit default container");
    IASVerifyInstanceHook(cloudKitMetaClass, NSSelectorFromString(@"containerWithIdentifier:"),
                          (IMP)IASForgedContainerWithIdentifier, @"CloudKit named container");
}

__attribute__((constructor)) static void IASInitialize(void) {
    @autoreleasepool {
        NSString *bundleIdentifier = [NSBundle mainBundle].bundleIdentifier;
        if (![bundleIdentifier isEqualToString:IASTargetBundleIdentifier]) {
            IASLog(@"refusing to initialize in non-test bundle %@",
                   bundleIdentifier ?: @"<nil>");
            return;
        }

        IASLog(@"ACTIVE INTERNAL SIMULATION loaded in %@", bundleIdentifier);
        IASInstallHooks();

        NSArray<NSNumber *> *retryDelays = @[@0.0, @0.5, @1.0, @2.0];
        for (NSNumber *delay in retryDelays) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                         (int64_t)(delay.doubleValue * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                IASInstallHooks();
            });
        }

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC),
                       dispatch_get_main_queue(), ^{
            IASVerifyHooks();
        });
    }
}
