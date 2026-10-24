# Step 8C-4 — Non-destructive DMG installation validation

**PASS. Recommend proceeding to GitHub Release v1.0, with the distribution limitations below. No publication performed.**

## DMG

Path: `/Users/seyoungseo/Documents/Xcode/USB App Launcher/USB App Launcher v1.0.dmg`

SHA-256: `ded233f3faa89d5041a92e18fb5fa2ed7c1da19cd02bbcbdb90d71aeecd7d7bd` — matches Step 8C-3 before and after validation. `hdiutil verify` passed. Read-only mount at a dedicated temporary path contained exactly USB App Launcher.app and Applications, a symbolic link to /Applications.

## Safe copy test

Copied with `ditto --rsrc --extattr --acl` into `/private/tmp/USB-Step8C4-Validation-1741d5hz/installation/USB App Launcher.app` without launching it. Both mounted and copied app/Helper passed strict nested codesign verification. No FinderInfo or ResourceFork attributes were found by recursive xattr inspection. No repair or re-signing was needed.

Every regular file SHA-256 and permission bits match between mounted app and copy. Signing identifiers, signature descriptions/CDHashes/designated requirements, and effective entitlements also match. Main identifier com.ssy523a.USBAppLauncher; Helper com.ssy523a.USBAppLauncher.Helper. Both remain ad-hoc signed. Main retains only user-selected read-only entitlement; Helper is empty.

Version 1.0, arm64 executables, minimum macOS 14 verified. Exactly one Helper and one com.ssy523a.USBAppLauncher.BackgroundAgent.plist with matching Label; no obsolete Helper plist.

## Existing installation protection

The existing /Applications/USB App Launcher.app remains present; its file hashes and permissions are unchanged across validation. Application Support JSON hash is unchanged. Only read-only inspections were performed on either location.

BackgroundAgent read-only launchctl summary was identical before and after:

```text
path = (submitted by smd.334)
state = running
pid = 784
last exit code = (never exited)
state = active
state = active
job state = running
```

No launch, replacement, registration, unregistration, restart or termination was requested. No build, Archive, signing, source/project edit, security-policy change, commit, push, or release publication occurred.

## Cleanup and limits

DMG unmounted cleanly. This step's temporary mount and installation-copy directory were removed; original DMG and all pre-existing candidates were retained.

This validates a native-tool copy into a temporary directory, not an actual /Applications replacement, Finder drag-and-drop, or fresh-machine Gatekeeper flow. Prior nine functional tests are user-reported and were not rerun. Apple Silicon/macOS 14+ only; ad-hoc signed, not notarized, recipient-Mac behavior not independently tested. Users may encounter Gatekeeper approval requirements and should use normal Privacy & Security procedures if they trust the source; no quarantine removal or security disabling is advised.

Only STEP8C-4.md was added to the repository. Packaging/copy validation found no problems. Publish the DMG with its checksum and these limitations when the user chooses to proceed.
