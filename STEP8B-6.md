# Step 8B-6 — Fresh LaunchAgent Release candidate

**PASS for Release build, bundle integration and ad-hoc signature validation. Live registration/execution remains NOT TESTED.**

## Configuration and build

Earlier changes renamed the project plist and updated its Label plus the two lookups in HelperRegistrationManager.swift. The first build was blocked by an obsolete copy reference. The user then corrected and saved both Copy Files phases; this continuation changed no source, project setting, signing configuration, plist, or user data.

- Main Bundle Identifier/signing identifier: `com.ssy523a.USBAppLauncher`.
- Helper signing identifier: `com.ssy523a.USBAppLauncher.Helper`.
- New LaunchAgent Label: `com.ssy523a.USBAppLauncher.BackgroundAgent`.
- Plist: `Contents/Library/LaunchAgents/com.ssy523a.USBAppLauncher.BackgroundAgent.plist`.
- Helper: `Contents/Helpers/USBAppLauncherHelper`.

One authorized Release validation build succeeded, including Helper, using arm64/macOS 14 minimum. Development-signed artifact: `/tmp/USB-Step8B6-Validated/Build/Products/Release/USB App Launcher.app`. Log: `/tmp/usb-step8b6-validated-build.log`.

Both original executable identities and strict nested signatures verified. Exactly one Helper and one new LaunchAgent plist are embedded; no obsolete Helper.plist is present anywhere in the app. Plist syntax passed. BundleProgram, USBAppLauncherHelper / --automation-service arguments, RunAtLoad=true and Aqua are preserved. Main and Helper permissions are 0755; both are arm64. Version 1.0/build 1 and AppIcon metadata/icon file are present.

## Ad-hoc candidate

`/private/tmp/USB-Step8B6-Distribution-4m042pn4/USB App Launcher.app`

Copied the complete Release app with `ditto --rsrc --extattr --acl`. Signed Helper first, then outer app using `codesign --force --sign - --identifier <unchanged-id> --entitlements <staging-plist> <target>`. No deep signing. Original Release artifact was not re-signed.

Both staged executables pass `codesign --verify --deep --strict --verbose=2`, including nested validation from the outer bundle. Both report Signature=adhoc and TeamIdentifier=not set. Identifiers match those above. Effective entitlements:

- Main: only `com.apple.security.files.user-selected.read-only=true`.
- Helper: empty dictionary.

No get-task-allow, team-bound application-identifier, Sandbox or privileged entitlement. Hardened Runtime remains disabled. Repeated bundle checks passed on the staged copy. Original file hashes/permissions remain unchanged; candidate file differences are confined to the two signed executables and resource seal. Plist, icon and other resources remain identical to the built artifact.

The existing App Intents metadata-extraction warning remains (no AppIntents.framework dependency). No Swift compiler warnings were reported.

## Manual validation — pending user action

1. Confirm old production/test registrations are Not Registered and no Helper remains. Any unregistration must be manual in the corresponding old app; no BTM reset.
2. Preserve the existing /Applications app, then manually copy this candidate into /Applications and launch that exact app.
3. Click Register once; complete normal background-item approval if requested. Verify the actual Helper PID/path in Activity Monitor and inspect `launchctl print gui/$(id -u)/com.ssy523a.USBAppLauncher.BackgroundAgent`.
4. Compare state, job state, runs, PID, last exit reason and LWCR identifier/category/team or cdhash requirements against the old failure. Enabled alone is insufficient. Stop if OS_REASON_CODESIGNING recurs; do not repeatedly retry or alter security policy.
5. If running, manually test USB Auto-Launch, graceful Auto-Quit, management-app independence and login startup. Save work before any user-initiated logout. Manually Unregister afterward if required.

The fresh Label is intended to avoid the earlier identity-specific constraints but success is not guaranteed until actual registration and execution are tested. Internet-download Gatekeeper behavior, other macOS versions and recipient policies remain unverified. This is arm64-only, not notarized, and no universal distribution compatibility is claimed.

Earlier preflight found no loaded old/test/new service and no running Helper; those checks were not repeated in this build-only continuation. No app/Helper was executed or installed, no service registered/unregistered, and no user JSON was touched. No DMG, commit or push. Only STEP8B-6.md was updated during this continuation, alongside external build/staging artifacts.
