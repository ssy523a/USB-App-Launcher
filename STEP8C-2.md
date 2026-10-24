# Step 8C-2 — Release metadata repair

**PASS: existing signatures preserved; working copy passes strict validation without rebuilding or re-signing.**

Source preserved: `/Users/seyoungseo/Documents/Xcode/USB App Launcher/USB-App-Launcher-Release/USB App Launcher.app`

Verified working copy: `/private/tmp/USB-Step8C2-Verified-uvkiaod3/USB App Launcher.app`

## Exact metadata findings and change

Recursive `xattr -lr` found only these attributes, both on the outer .app directory:

- `com.apple.FinderInfo` (no printable value in the listing).
- `com.apple.fileprovider.fpfs#P` (value displayed as byte 0x01).

No descendant FinderInfo, ResourceFork, quarantine, or provenance attributes were listed. Copied the complete bundle with `ditto --rsrc --extattr --acl`. On the copy only, removed exactly `com.apple.FinderInfo` from the outer app using `xattr -d com.apple.FinderInfo <copied-app>`. The unrelated file-provider attribute was retained. No recursive clearing, quarantine removal, or security-policy change.

## Verification

Main app and embedded Helper both pass `codesign --verify --deep --strict --verbose=2`. No re-signing was required. Before/after signature descriptions, designated requirements, CDHashes and entitlements match (excluding only the executable's filesystem path). Both remain ad-hoc signed, no Team Identifier, Hardened Runtime disabled.

Main identifier remains com.ssy523a.USBAppLauncher; Helper identifier remains com.ssy523a.USBAppLauncher.Helper. Main retains only user-selected read-only=true; Helper entitlements remain empty. No get-task-allow or privileged entitlements added.

Every regular file's SHA-256 and permission bits match the preserved original, including executables, Info.plist, icon/resources, signature seal and LaunchAgent. Executable permissions remain as in the original. Exactly one Helper and one BackgroundAgent plist remain. Label com.ssy523a.USBAppLauncher.BackgroundAgent, BundleProgram Contents/Helpers/USBAppLauncherHelper, --automation-service, RunAtLoad and Aqua are unchanged. Version/icon metadata are unchanged.

Original file hashes/permissions and recursive extended-attribute listing were rechecked and are unchanged. Only the copied outer-directory FinderInfo attribute was removed.

## Origin, prevention and readiness

FinderInfo is Finder metadata; the accompanying file-provider attribute suggests file-provider involvement, but the exact operation or process that attached FinderInfo is not established. The successful verification after removing that attribute isolates it as the blocker in this copy; the retained file-provider attribute did not prevent verification.

Use this verified copy as the packaging input. Avoid adding custom Finder icons or other Finder metadata to the app bundle. Keep packaging staging separate from synced/file-provider-managed folders where practical, and run strict signature verification immediately before and after future packaging. If metadata recurs, inspect it and remove only confirmed offending attributes from a separate copy; do not use blanket xattr clearing.

**Ready as a DMG packaging input on signature/bundle-integrity grounds.** No DMG was created. This does not establish notarization, downloaded-file Gatekeeper acceptance, or universal recipient compatibility. The user's nine passing installed-app tests were not repeated. Preserve this temporary working copy until an approved packaging step uses it; temporary directories are not durable release archives.

No changes to source/project, original candidate, installed application, live service, user data, BTM or Gatekeeper. No build, Archive, re-sign, commit or push. Only this report was added to the repository.
