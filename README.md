# InfuseSecurityTest

InfuseSecurityTest 1.1.1 is a defensive, telemetry-only ElleKit tweak for
authorized testing of Infuse on jailbroken tvOS. It targets only
`com.firecore.infuse`, observes selected security-relevant calls, and returns
the original application result unchanged.

It does **not** unlock paid features, alter purchase state, patch the Infuse
executable, repackage an IPA, fabricate app-group containers, or disable
CloudKit. No telemetry is stored or sent over the network.

## Supported test environment

- Apple TV 4K (`AppleTV6,2`)
- tvOS 26.6, arm64
- rootful palera1n jailbreak
- PurePKG
- ElleKit 1.1.3-palera1n2, providing `mobilesubstrate`
- Infuse bundle identifier `com.firecore.infuse`

The binary has a tvOS 17.0 minimum deployment target and is packaged for the
`appletvos-arm64` architecture.

## Install with PurePKG

1. Open PurePKG on the Apple TV.
2. Open **Browse**, select **+**, and add this source:

   ```text
   https://pepe424.github.io/infuseBypassAppleTV/
   ```

3. Refresh sources.
4. Search for **InfuseSecurityTest** and install version **1.1.1**.
5. Force-quit and reopen Infuse. If the tweak does not load, reboot userspace.

The package conflicts with and replaces the previous
`com.pepe424.infusebypassappletv` package, so both versions cannot load at the
same time.

Direct package download:
[com.pepe424.infusesecuritytest_1.1.1_appletvos-arm64.deb](https://pepe424.github.io/infuseBypassAppleTV/debs/com.pepe424.infusesecuritytest_1.1.1_appletvos-arm64.deb)

## Installed files

The DEB installs only:

```text
/Library/MobileSubstrate/DynamicLibraries/InfuseSecurityTest.dylib
/Library/MobileSubstrate/DynamicLibraries/InfuseSecurityTest.plist
```

On this rootful setup, `/Library/MobileSubstrate/DynamicLibraries` points to
`/usr/lib/TweakInject`. The filter plist restricts ElleKit injection to
`com.firecore.infuse`. The Infuse application and IPA remain untouched.

## What it observes

The tweak uses a constructor entry point and pass-through Objective-C runtime
hooks for:

- legacy and StoreKit 2 `iapVersionStatus` results;
- StoreKit 2 `isFeaturePurchased:tillDate:` results;
- app-group container lookups; and
- CloudKit default and named-container lookups.

All hooked methods call the original implementation and return its result
unchanged.

## Verify on the Apple TV

From an SSH session, stream the diagnostic messages while opening and using
Infuse:

```sh
log stream --style compact \
  --predicate 'eventMessage CONTAINS[c] "InfuseSecurityTest"'
```

Expected startup output includes:

```text
[InfuseSecurityTest] loaded in com.firecore.infuse; telemetry is pass-through and stores no data
```

You should also see an `observing` line for each hook whose target class and
selector are available. Missing optional class hooks are retried once on the
main queue.

## Build from source

Install Theos with a tvOS SDK, then run:

```sh
THEOS="$HOME/theos" make clean package FINALPACKAGE=1
```

The resulting DEB is written to `packages/`. To rebuild the DEB and refresh
the GitHub Pages repository metadata in `docs/`, run:

```sh
THEOS="$HOME/theos" ./scripts/build-repository.sh
```

The current package is built from:

- `InfuseSecurityTest.mm` — constructor and pass-through hooks;
- `InfuseSecurityTest.plist` — bundle filter;
- `Makefile` — Theos tvOS tweak configuration; and
- `control` — Debian package metadata.

The original `InfuseBypass.xcodeproj`, framework source, and legacy filter
plists are retained for repository history. They are not compiled or installed
by the current Theos package.

## Uninstall

Remove **InfuseSecurityTest** in PurePKG, perform the queued actions, and then
force-quit and reopen Infuse or reboot userspace.

## Version history

See [CHANGELOG.md](CHANGELOG.md). For PurePKG usage, see the
[palera1n documentation](https://docs.palera.in/installing-palera1n-atv/using-purePKG.html).
