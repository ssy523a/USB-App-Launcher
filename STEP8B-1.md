# Step 8B-1 — Certificate-free staged signing

**PASS for ad-hoc signing and bundle integrity only.** SMAppService and recipient-Mac compatibility remain unverified. The user explicitly approved removing the staged Helper's team-prefixed application-identifier entitlement after the initial preflight pause.

## Artifact and commands

Reused the valid Step 8A Release artifact and existing metadata-preserving staged copy; no rebuild. Candidate:

`/private/tmp/USB-Step8B-1-AdHoc-Pending-3_2ka65a/USB App Launcher.app`

The directory retains its original “Pending” name, but the app is now ad-hoc signed. Only two Mach-O executables were present as the signing targets. Signed the nested Helper first, then the outer app, with these commands (paths abbreviated below):

```sh
stage=/private/tmp/USB-Step8B-1-AdHoc-Pending-3_2ka65a
app="$stage/USB App Launcher.app"
codesign --force --sign - --identifier devplaceholder.VC4RZVAC.USB-App-Launcher.USBAppLauncherHelper --entitlements "$stage/helper-adhoc-entitlements.plist" "$app/Contents/Helpers/USBAppLauncherHelper"
codesign --force --sign - --identifier devplaceholder.VC4RZVAC.USB-App-Launcher --entitlements "$stage/main-adhoc-entitlements.plist" "$app"
```

Both commands succeeded. The staging-only entitlement plists contain an empty dictionary for Helper and only user-selected read-only=true for main. No deep signing or certificate was used.

## Verification results

- Main and embedded Helper independently passed `codesign --verify --deep --strict --verbose=2`; outer verification also validated nested code.
- Both report `Signature=adhoc`, `TeamIdentifier=not set`, flags `0x2(adhoc)`. Hardened Runtime remains disabled; no signing-setting change was made.
- Main effective entitlements: **only** `com.apple.security.files.user-selected.read-only=true`.
- Helper effective entitlements: **empty dictionary**.
- Neither contains get-task-allow, application-identifier, App Sandbox, or privileged entitlements. Effective entitlements were extracted with `codesign -d --entitlements - --xml`; an initial inspection without --xml returned human-readable output and was corrected without re-signing.
- Code-signing identifiers remain `devplaceholder.VC4RZVAC.USB-App-Launcher` and `devplaceholder.VC4RZVAC.USB-App-Launcher.USBAppLauncherHelper`. Main bundle identifier is unchanged.
- Exactly one embedded Helper, at `Contents/Helpers/USBAppLauncherHelper`, mode 0755; exactly one intended LaunchAgent plist, at `Contents/Library/LaunchAgents/com.ssy523a.USBAppLauncher.Helper.plist`.
- Plist syntax passed. Label is unchanged; BundleProgram is `Contents/Helpers/USBAppLauncherHelper`; ProgramArguments are `USBAppLauncherHelper`, `--automation-service`; RunAtLoad=true and Aqua session unchanged.
- Version 1.0, build 1, and AppIcon metadata preserved. File inventory and resource hashes match the original. Differences are confined to the two signed executable files and `Contents/_CodeSignature/CodeResources`. Icon and LaunchAgent bytes are unchanged.
- Original bundle and Helper still pass strict verification and retain their Apple Development signatures. No signing command targeted the original.

## Limits and next action

Gatekeeper assessment was omitted: this step establishes code-signature integrity, not Gatekeeper acceptance. No app or Helper was executed, installed, registered, or unregistered. No quarantine/security policy or user configuration was touched. No project/source/signing settings were changed, no DMG created, and no commit or push performed. Only this repository report was updated; signing support files are outside the repository in staging.

**Step 8B-2 may proceed with separate approval** to test actual registration and recipient-Mac compatibility. Passing codesign does not establish SMAppService compatibility, trusted distribution, or notarization. No Step 8B-2 action was performed.
