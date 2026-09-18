# InfuseAttackSimulation (internal only)

This package is an active attack simulator for the internal Infuse security
test build. Both its ElleKit filter and runtime guard require the exact bundle
identifier `com.firecore.infuse.securitytest`. It does not target production
`com.firecore.infuse` and must not be published in the public PurePKG feed.

The simulator reproduces the historical attack paths by forging purchase and
feature results, redirecting app-group lookups, and forcing CloudKit container
lookups to return `nil`. It also reports whether each hook remains active or
was blocked/reverted by the test build.

## Build

From this directory:

```sh
THEOS="$HOME/theos" make clean package FINALPACKAGE=1
```

The output package is written to `packages/` and has package identifier
`com.pepe424.infusesecuritytestattack`.

## Install on the authorized test device

Because the repository is private, copy the DEB to the Apple TV over SSH and
install it locally rather than publishing it through the public Pages feed:

```sh
scp packages/com.pepe424.infusesecuritytestattack_1.0.0~internal1_appletvos-arm64.deb root@APPLE_TV_IP:/tmp/
ssh root@APPLE_TV_IP
dpkg -i /tmp/com.pepe424.infusesecuritytestattack_1.0.0~internal1_appletvos-arm64.deb
```

Force-quit and reopen the internal Infuse build or reboot userspace.

## Verify

```sh
log stream --style compact \
  --predicate 'eventMessage CONTAINS[c] "InfuseAttackSimulation"'
```

The verification lines report each path as `ACTIVE`, `BLOCKED/REVERTED`, or
`unavailable`. A successful defense should block injection, terminate the test
process safely, or report the relevant hooks as `BLOCKED/REVERTED` while
preserving legitimate entitlement behavior.
