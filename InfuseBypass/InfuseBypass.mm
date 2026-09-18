//
//  InfuseSecurityTest.mm
//
//  Defensive, pass-through telemetry for an authorized Infuse security test.
//  This code observes selected calls and always preserves the original result.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static NSString *const ISTTargetBundleIdentifier = @"com.firecore.infuse";

static IMP ISTOriginalObjCIAPVersionStatus = NULL;
static IMP ISTOriginalSwiftIAPVersionStatus = NULL;
static IMP ISTOriginalIsFeaturePurchased = NULL;
static IMP ISTOriginalContainerURL = NULL;
static IMP ISTOriginalDefaultContainer = NULL;
static IMP ISTOriginalContainerWithIdentifier = NULL;

static void ISTLog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);

static void ISTLog(NSString *format, ...) {
    va_list arguments;
    va_start(arguments, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    NSLog(@"[InfuseSecurityTest] %@", message);
}

static NSInteger ISTObservedObjCIAPVersionStatus(id self, SEL selector) {
    NSInteger result = ((NSInteger (*)(id, SEL))ISTOriginalObjCIAPVersionStatus)(self, selector);
    ISTLog(@"%@: iapVersionStatus returned %lld (unchanged)",
           NSStringFromClass([self class]), (long long)result);
    return result;
}

static NSInteger ISTObservedSwiftIAPVersionStatus(id self, SEL selector) {
    NSInteger result = ((NSInteger (*)(id, SEL))ISTOriginalSwiftIAPVersionStatus)(self, selector);
    ISTLog(@"%@: iapVersionStatus returned %lld (unchanged)",
           NSStringFromClass([self class]), (long long)result);
    return result;
}

static BOOL ISTObservedIsFeaturePurchased(id self, SEL selector, NSInteger feature, id *tillDate) {
    BOOL result = ((BOOL (*)(id, SEL, NSInteger, id *))ISTOriginalIsFeaturePurchased)(
        self, selector, feature, tillDate);
    ISTLog(@"%@: isFeaturePurchased:%lld returned %@ (unchanged)",
           NSStringFromClass([self class]), (long long)feature, result ? @"YES" : @"NO");
    return result;
}

static NSURL *ISTObservedContainerURL(id self, SEL selector, NSString *groupIdentifier) {
    NSURL *result = ((NSURL *(*)(id, SEL, NSString *))ISTOriginalContainerURL)(
        self, selector, groupIdentifier);
    ISTLog(@"NSFileManager app-group lookup for %@ returned %@ (unchanged)",
           groupIdentifier ?: @"<nil>", result ? @"a URL" : @"nil");
    return result;
}

static id ISTObservedDefaultContainer(id self, SEL selector) {
    id result = ((id (*)(id, SEL))ISTOriginalDefaultContainer)(self, selector);
    ISTLog(@"CKContainer defaultContainer returned %@ (unchanged)",
           result ? @"an object" : @"nil");
    return result;
}

static id ISTObservedContainerWithIdentifier(id self, SEL selector, NSString *identifier) {
    id result = ((id (*)(id, SEL, NSString *))ISTOriginalContainerWithIdentifier)(
        self, selector, identifier);
    ISTLog(@"CKContainer lookup for %@ returned %@ (unchanged)",
           identifier ?: @"<nil>", result ? @"an object" : @"nil");
    return result;
}

static void ISTInstallInstanceHook(Class targetClass, SEL selector, IMP replacement,
                                   IMP *original) {
    if (targetClass == Nil || *original != NULL) {
        return;
    }

    Method method = class_getInstanceMethod(targetClass, selector);
    if (method == NULL) {
        return;
    }

    *original = method_setImplementation(method, replacement);
    ISTLog(@"observing -[%@ %@]", NSStringFromClass(targetClass),
           NSStringFromSelector(selector));
}

static void ISTInstallClassHook(Class targetClass, SEL selector, IMP replacement,
                                IMP *original) {
    if (targetClass == Nil) {
        return;
    }
    ISTInstallInstanceHook(object_getClass(targetClass), selector, replacement, original);
}

static void ISTInstallHooks(void) {
    Class objcIAPClass = objc_getClass("FCInAppPurchaseServiceFreemium");
    ISTInstallInstanceHook(objcIAPClass, NSSelectorFromString(@"iapVersionStatus"),
                           (IMP)ISTObservedObjCIAPVersionStatus,
                           &ISTOriginalObjCIAPVersionStatus);

    Class swiftIAPClass = objc_getClass("_TtC6infuse31InAppPurchaseServiceFreemiumSK2");
    ISTInstallInstanceHook(swiftIAPClass, NSSelectorFromString(@"iapVersionStatus"),
                           (IMP)ISTObservedSwiftIAPVersionStatus,
                           &ISTOriginalSwiftIAPVersionStatus);
    ISTInstallInstanceHook(swiftIAPClass, NSSelectorFromString(@"isFeaturePurchased:tillDate:"),
                           (IMP)ISTObservedIsFeaturePurchased,
                           &ISTOriginalIsFeaturePurchased);

    ISTInstallInstanceHook([NSFileManager class],
                           @selector(containerURLForSecurityApplicationGroupIdentifier:),
                           (IMP)ISTObservedContainerURL, &ISTOriginalContainerURL);

    Class cloudKitClass = objc_getClass("CKContainer");
    ISTInstallClassHook(cloudKitClass, NSSelectorFromString(@"defaultContainer"),
                        (IMP)ISTObservedDefaultContainer, &ISTOriginalDefaultContainer);
    ISTInstallClassHook(cloudKitClass, NSSelectorFromString(@"containerWithIdentifier:"),
                        (IMP)ISTObservedContainerWithIdentifier,
                        &ISTOriginalContainerWithIdentifier);
}

__attribute__((constructor)) static void ISTInitialize(void) {
    @autoreleasepool {
        NSString *bundleIdentifier = [NSBundle mainBundle].bundleIdentifier;
        if (![bundleIdentifier isEqualToString:ISTTargetBundleIdentifier]) {
            ISTLog(@"refusing to initialize in unexpected bundle %@",
                   bundleIdentifier ?: @"<nil>");
            return;
        }

        ISTLog(@"loaded in %@; telemetry is pass-through and stores no data",
               bundleIdentifier);
        ISTInstallHooks();

        // Swift and CloudKit classes may become visible after tweak construction.
        // A main-queue retry installs only hooks that were unavailable above.
        dispatch_async(dispatch_get_main_queue(), ^{
            ISTInstallHooks();
        });
    }
}
