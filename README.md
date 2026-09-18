# InfuseBypassAppleTV

A defensive, telemetry-only ElleKit tweak for authorized testing of Infuse on
tvOS. It targets `com.firecore.infuse`, observes selected security-relevant
calls, and always returns the original application result unchanged.

It does **not** unlock paid features, patch the Infuse executable, repackage an
IPA, fabricate app-group containers, or disable CloudKit.

## Install with PurePKG

Requirements:

- Apple TV 4K (`AppleTV6,2`) on a rootful palera1n jailbreak;
- PurePKG;
- ElleKit providing the `mobilesubstrate` package; and
- Infuse installed with bundle identifier `com.firecore.infuse`.

Add this repository in PurePKG:

```text
https://pepe424.github.io/infuseBypassAppleTV/
```

On the Apple TV:

1. Open **PurePKG**.
2. Open **Browse** and select the **+** button.
3. Enter the repository URL above and select **OK**.
4. Refresh sources if PurePKG does not refresh automatically.
5. Search for **InfuseBypassAppleTV**.
6. Select **Install**, open **Queued**, and choose **Perform Actions**.
7. Force-quit and reopen Infuse, or reboot userspace if the tweak does not load.

The package installs only:

```text
/Library/MobileSubstrate/DynamicLibraries/InfuseBypassAppleTV.dylib
/Library/MobileSubstrate/DynamicLibraries/InfuseBypassAppleTV.plist
```

ElleKit loads the tweak only into `com.firecore.infuse` through the bundle
filter in `InfuseBypassAppleTV.plist`. The Infuse IPA is not modified.

## Verify telemetry

From an SSH session to the Apple TV, stream the diagnostic messages while
opening and using Infuse:

```sh
log stream --style compact \
  --predicate 'eventMessage CONTAINS[c] "InfuseBypassAppleTV"'
```

Expected startup output includes a line similar to:

```text
[InfuseBypassAppleTV] loaded in com.firecore.infuse; telemetry is pass-through and stores no data
```

The tweak observes:

- legacy and StoreKit 2 `iapVersionStatus` results;
- StoreKit 2 `isFeaturePurchased:tillDate:` results;
- app-group container lookups; and
- CloudKit default and named-container lookups.

It stores no telemetry and sends no telemetry over the network.

## Build from source

The Theos build targets arm64 tvOS 17.0 or later. The original Xcode project
uses a tvOS 26.1 deployment target, while the package keeps a tvOS 17.0 minimum
for compatibility with the tvOS 26.6 test device.

```sh
THEOS="$HOME/theos" make clean package FINALPACKAGE=1
```

The resulting `appletvos-arm64` package is written to `packages/`. The package
feed in `docs/` is published with GitHub Pages.

PurePKG usage reference: https://docs.palera.in/installing-palera1n-atv/using-purePKG.html
