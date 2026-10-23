# Step 8B-4 — Final production identity

**CONDITIONAL PASS:** Release build and staged ad-hoc signatures passed; final-identity registration/execution still requires manual validation.

## Preflight and changes

Git preflight: STEP8B-2.md was already staged; STEP8B-1.md and STEP8B-3.md were untracked. These files and their staging state were preserved. No unrelated source edits were present.

Read-only launchctl checks found neither production nor AdHocTest service loaded in gui/501. An unrestricted pgrep check found no running USBAppLauncherHelper. Initial restricted process enumeration failed; the read-only retry resolved that limitation. A BTM dump attempt failed with an authorization error; no authorization workaround/reset was attempted. Previously reported disabled records were not removed.

Changed only PRODUCT_BUNDLE_IDENTIFIER for both targets through Xcode's build-setting API (Debug and Release entries; four replacements). No direct project-file edits. Final identities:

- Main: com.ssy523a.USBAppLauncher
- Helper: com.ssy523a.USBAppLauncher.Helper
- LaunchAgent Label and plist: com.ssy523a.USBAppLauncher.Helper / com.ssy523a.USBAppLauncher.Helper.plist
- App name: USB App Launcher

Existing plist, SMAppService lookup, Copy Files phases, target/executable names, and display name already match; no edits were needed. The Helper's existing OTHER_CODE_SIGN_FLAGS derives its signing identifier from PRODUCT_BUNDLE_IDENTIFIER. No automation/UI source changed.

Storage remains ~/Library/Application Support/USB App Launcher/registered-devices.json; the path is explicitly named, not derived from Bundle Identifier. No migration or user-data access/change was necessary.

## Build and signing

One Release build succeeded, arm64/macOS 14 minimum, including Helper. The only reported build warning was the existing App Intents metadata-extraction warning (no AppIntents.framework dependency); no Swift compiler warnings were reported. Log: /tmp/usb-step8b4-build.log. Original build: /tmp/USB-Step8B4-Release/Build/Products/Release/USB App Launcher.app.

Development signing configuration was retained; original main/Helper signatures use the existing Apple Development identity and pass strict nested verification with the final signing identifiers. Debug was not rebuilt; normal signing settings remain unchanged.

Distribution candidate:

`/private/tmp/USB-Step8B4-Distribution-a7fw62jl/USB App Launcher.app`

Workflow: copy the complete app using ditto --rsrc --extattr --acl; explicitly sign Helper first, then app with `codesign --force --sign - --identifier <final-id> --entitlements <staging-plist> <target>`. No deep signing. Stage-only entitlement plists are alongside the candidate. Do not ship the raw development-signed build as this candidate.

Both staged signatures pass strict nested verification and report ad-hoc signing with the final identifiers. Main effective entitlements contain only user-selected read-only=true; Helper is empty. No get-task-allow, team-bound application-identifier, Sandbox, or privileged entitlement is carried into staging. Hardened Runtime was not enabled. Original build hashes were preserved; staged changes are confined to signed executables and the resource seal.

Exactly one Helper and one intended LaunchAgent plist; plist syntax passed. Executable mode 0755, BundleProgram Contents/Helpers/USBAppLauncherHelper, --automation-service, RunAtLoad=true, Aqua unchanged. Icon/resources, version and other bundle metadata are unchanged by staging.

## Remaining test and limitations

The user's Step 8B-3 report confirms the separate AdHocTest identity ran with cdhash-based LWCR on this Mac. It does not prove why the old identity failed or that these final identities will work.

**The final LaunchAgent Label intentionally reuses the old production Label.** Disabled BTM records may still influence the final service even with the new main Bundle Identifier. No fresh-identity guarantee is made, and no service was registered to test this.

First Step 8B-5 manual action: confirm AdHocTest and old production apps show Not Registered and no Helper is running; if necessary manually unregister from the corresponding app before installing the final candidate. Do not install/register this candidate until that step is explicitly approved. Keep existing apps/builds as backups. Then test final-identity registration, actual installed Helper path/PID and launch constraints; stop on a codesigning failure rather than resetting BTM or retrying repeatedly.

Single-Mac ad-hoc success does not establish internet-download Gatekeeper acceptance or other users' policies. Artifact is arm64-only, macOS 14+. No Developer ID/notarization is supplied.

Files changed: USB App Launcher.xcodeproj/project.pbxproj (via Xcode API), STEP8B-4.md. No install, registration, service mutation, configuration edit, DMG, commit, push, Step 8B-5, or Step 8C work was performed.
