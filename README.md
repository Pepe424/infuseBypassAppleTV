# Infuse Security Test for tvOS

This repository builds a rootful ElleKit/MobileSubstrate tweak for authorized,
defensive testing of Infuse (`com.firecore.infuse`). It does not patch or
repackage the Infuse IPA and it does not change purchase, app-group, or
CloudKit results.

The tweak observes the same security-relevant call sites investigated by the
original framework and writes pass-through diagnostics to Apple's unified log:

- legacy and StoreKit 2 `iapVersionStatus` results;
- StoreKit 2 `isFeaturePurchased:tillDate:` results;
- app-group container lookups; and
- CloudKit default and named-container lookups.

No telemetry is sent over the network or stored by the tweak. The original
return value from every observed method is returned unchanged.

## Build

The package targets arm64 tvOS 17.0 or later. The existing Xcode project had a
tvOS 26.1 deployment target; the Theos target remains at 17.0 so the package is
compatible with the tvOS 26.6 test device while avoiding an unnecessary 26.x
minimum.

```sh
THEOS="$HOME/theos" make clean package FINALPACKAGE=1
```

The resulting `appletvos-arm64` DEB is written to `packages/`. Its payload is:

```text
/Library/MobileSubstrate/DynamicLibraries/InfuseSecurityTest.dylib
/Library/MobileSubstrate/DynamicLibraries/InfuseSecurityTest.plist
```

Install the DEB through PurePKG, then relaunch Infuse. ElleKit satisfies the
declared `mobilesubstrate` dependency. To inspect events over SSH:

```sh
log stream --style compact \
  --predicate 'eventMessage CONTAINS[c] "InfuseSecurityTest"'
```

The legacy Xcode project remains in the repository for provenance, but package
builds use the Theos `Makefile` and do not embed a framework into the app.
