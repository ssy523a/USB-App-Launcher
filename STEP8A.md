# Step 8A — Focused Release Audit

Date: 2026-10-24. **CONDITIONAL PASS for build/bundle readiness; not cleared for public distribution.** No implementation or signing changes were made.

## Build and bundle

Release main app and dependent Helper built successfully for arm64, minimum macOS 14.0. The first restricted command-line attempt failed because Swift macro-plugin execution returned malformed responses; one approved unrestricted retry succeeded with unchanged settings. No Debug build or functional regression tests were repeated. Xcode's BuildProject tool has no Release configuration parameter, so the established explicit `xcodebuild -configuration Release` route was used.

Product: `/tmp/USB-Step8A-Release/Build/Products/Release/USB App Launcher.app`. Log: `/tmp/usb-step8a-release-build.log`.

| Check | Result |
| --- | --- |
| Embedded Helper | Exactly one, `Contents/Helpers/USBAppLauncherHelper` |
| LaunchAgent plist | Exactly one, `Contents/Library/LaunchAgents/com.ssy523a.USBAppLauncher.Helper.plist`; plutil passed |
| Label | `com.ssy523a.USBAppLauncher.Helper` |
| BundleProgram | `Contents/Helpers/USBAppLauncherHelper`; executable present |
| ProgramArguments | `USBAppLauncherHelper`, `--automation-service` |
| Startup/session | RunAtLoad=true; LimitLoadToSessionType=Aqua; no KeepAlive key |
| Main/Helper permissions | Both 0755; both arm64 (not an Intel/universal artifact) |
| Metadata | Version 1.0, build 1; AppIcon name and AppIcon.icns present |
| Nested signatures | App and Helper passed `codesign --verify --deep --strict` |

The relative executable location is suitable for moving the intact bundle into /Applications. This audit did not install it or execute the Helper. Earlier Step 6B functional results are reused, not represented as tests of this Release artifact on another Mac.

## Actual signing and entitlements

Both binaries use **Apple Development: SE YOUNG SEO (MJ23CHAN6P)**, Team Identifier **X3P895EA4K**. Neither is ad-hoc nor Developer ID signed. Main identifier remains `devplaceholder.VC4RZVAC.USB-App-Launcher`; Helper adds `.USBAppLauncherHelper`.

Effective Release entitlements:

- Main: `com.apple.security.files.user-selected.read-only=true`, **`com.apple.security.get-task-allow=true`**.
- Helper: `com.apple.application-identifier=X3P895EA4K.devplaceholder.VC4RZVAC.USB-App-Launcher.USBAppLauncherHelper`, **`com.apple.security.get-task-allow=true`**.
- Neither has `com.apple.security.app-sandbox`; project settings explicitly disable Sandbox for both. Both signature flags are `0x0`: **Hardened Runtime is not enabled**.

Successful local signing does not establish current paid membership, suitability of a development certificate for redistribution, or recipient trust. The development-only debugging entitlement in both Release binaries is a release-hardening issue to resolve before shipping. Proposed smallest follow-up, requiring approval: prepare a separately staged distribution-signing candidate without get-task-allow and evaluate certificate-free signing and its resulting entitlements. Do not mechanically carry certificate-bound identity entitlements into an ad-hoc candidate. No settings or entitlements were altered here.

## Free DMG feasibility and remaining uncertainty

The bundle layout is mechanically suitable for a DMG with an Applications shortcut; a DMG itself does not supply signing trust or notarization. Certificate-free macOS ad-hoc signing seals code but does not provide an Apple-certified developer identity or Team Identifier. This is distinct from both the current development signing and Developer ID distribution signing; it is also distinct from iOS “Ad Hoc” provisioning.

**Ad-hoc SMAppService LaunchAgent compatibility is unverified.** Targeted Apple documentation checks did not establish a guarantee for this exact case. No ad-hoc artifact was created and no service registration was attempted. Local signature validation and prior development-signed registration tests do not prove that a recipient can register or run an ad-hoc Helper. Nor does this audit prove that ad-hoc registration is categorically impossible. That uncertainty blocks claiming a working certificate-free distribution route. See Apple's [SMAppService documentation](https://developer.apple.com/documentation/servicemanagement/smappservice).

The local read-only `spctl --assess --type execute` returned “internal error in Code Signing subsystem” (exit 1). This is an inconclusive tooling result, not evidence of Gatekeeper acceptance or a specific policy rejection; it was not repeatedly retried. Expect an unidentified/unnotarized-app warning or block for a downloaded certificate-free build. Where macOS permits it and the recipient trusts the source, Apple's supported approval path is System Settings → Privacy & Security → Open Anyway after the initial attempt. It is not guaranteed under every system policy and does not by itself prove background-service approval. No quarantine removal or security disabling is proposed. [Apple's safe-opening guidance](https://support.apple.com/en-gb/102445).

## Diagnostics reused

- App Intents metadata-extraction warning: observed again, nonblocking; no Swift compiler warnings in the successful build log.
- Bookmark `sandbox_extension_consume failed: 22`: previously nonblocking/no demonstrated failure, per STEP6A/STEP6B/STEP7; not reinvestigated.
- AppKit window-focus, ViewBridge cancellation, task-port access diagnostics: distribution impact **unverified**; no matching prior classification was found in available root reports and none was exercised by this build-only audit. Not treated as demonstrated blockers.
- STEP5D.md was not present in this checkout; its summarized findings in STEP6A and later reports were reused.
- The inspection command's `codesign --entitlements :-` syntax emitted a deprecation warning; this is an audit-command warning, not an app build defect.

## Next steps, not performed

**Single recommended action:** approve a narrowly scoped Step 8B distribution-signing and recipient-compatibility test before creating a DMG.

Step 8B should validate an explicitly approved certificate-free candidate on a separate Mac/test environment: normal downloaded/quarantined first launch, user installation into /Applications, registration/approval, actual Helper execution, login startup, unregistration, and re-registration/update identity behavior. Preserve the existing data and production service on this Mac. Verify the selected candidate has no unintended development entitlements. Do not promise support until these checks pass.

Step 8C, only after that decision and separate approval: package the verified artifact with an Applications shortcut, recheck signatures/bundle contents after packaging, and provide architecture/minimum-OS/security-approval instructions. Developer ID signing and notarization remain unavailable and outside this audit.

Only repository file added/modified for this audit: `STEP8A.md`. No registration, login-item changes, source changes, data changes, signing-setting changes, DMG creation, installation, commit, or push.
