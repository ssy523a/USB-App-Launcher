# Step 8B-3 — Isolated ad-hoc identity experiment

**CONDITIONAL PASS:** isolated identity candidate prepared and signatures verified; live SMAppService test NOT TESTED.

## Evidence and identity dependencies

User-reported Step 8B-2 result: installed management app launches; registration displays Enabled, but launchd reports not running, runs=1, spawn failed, OS_REASON_CODESIGNING. Generated LWCR requires validation category 3 and Team X3P895EA4K; ad-hoc Helper has no team. User reports manual unregistration removed the loaded service, while disabled BTM records retain that team. These observations suggest identity-related constraints but do not establish stale metadata as the cause. They were not independently re-collected here.

`HelperRegistrationManager.swift` hardcodes the plist filename in SMAppService.agent and its bundle-presence check. It does not hardcode the plist Label or signing identifiers. Therefore the test preserves the filename and executable paths while changing the Label and signing identities. No source changes, rebuild, or Mach-O patching were needed. Targeted Helper startup/ownership searches found no matching hardcoded production identity dependency.

## Prepared candidate

`/private/tmp/USB-Step8B-3-Isolated-p3t981va/USB App Launcher AdHoc Test.app`

- Main CFBundleIdentifier and signing identifier: `com.ssy523a.USBAppLauncher.AdHocTest`.
- Helper signing identifier and LaunchAgent Label: `com.ssy523a.USBAppLauncher.AdHocTest.Helper`.
- Bundle/display name: USB App Launcher AdHoc Test. Existing compiled window/About strings still say USB App Launcher; identify the test by its Finder path.
- Plist filename deliberately remains `Contents/Library/LaunchAgents/com.ssy523a.USBAppLauncher.Helper.plist` to satisfy the compiled lookup. Its Label is the new test identity; filename is not the launchd job Label. Filename independence has not been tested with live registration.
- BundleProgram remains `Contents/Helpers/USBAppLauncherHelper`; ProgramArguments remain USBAppLauncherHelper, --automation-service. RunAtLoad and Aqua unchanged.

Copied the Step 8B-1 artifact using ditto with metadata preservation. Signed Helper first, then app, using `codesign --force --sign - --identifier <new-id> --entitlements <staging-plist> <target>`. No deep signing. Both passed strict nested verification and report ad-hoc signatures/no Team Identifier. Main retains only user-selected read-only=true; Helper entitlements empty. No get-task-allow, Sandbox, privileged entitlements, or Hardened Runtime added.

Exactly one Helper (0755) and one LaunchAgent plist; plutil passed. Original candidate file hashes unchanged. Changes in the new copy are confined to Info.plist, LaunchAgent plist, signed executable files, and signature resource seal. Existing icon, version 1.0/build 1, arm64 architecture, macOS 14 minimum, and executable paths are preserved.

## Manual test — only after explicit approval

1. Confirm production/development service remains unregistered and no development/test Helper is running. Do not reset BTM or remove old records. No live state was changed or independently reconfirmed in this preparation.
2. Once this live experiment is approved, manually copy **USB App Launcher AdHoc Test.app** to /Applications as a separate app; do not replace USB App Launcher.app. Open this exact copy and click Register once, completing normal approval if requested.
3. Record UI status/exact error, actual Helper PID and executable path, and read-only output of `launchctl print gui/$(id -u)/com.ssy523a.USBAppLauncher.AdHocTest.Helper`. Capture state, runs, last exit reason, job state, and LWCR identifier/category/team requirements. Enabled alone is insufficient.
4. If it fails, stop; do not repeatedly register or alter signing. If it succeeds, this is evidence for identity-specific/stale-policy behavior, not proof of root cause or permission to migrate production identities.
5. After recording results, manually Unregister using this test app and confirm its job/process exits. Do not remove configuration or reset BTM.

**Runtime isolation limitation:** only app/service/signing identity is isolated. This unchanged Helper still reads the existing USB rules and uses the shared exclusive ownership lock. Starting it may launch configured apps for already-connected devices. No test app/Helper was executed here. Disconnect registered USB devices and close test target apps only as appropriate under the approved manual plan; do not edit JSON for this experiment.

Interpretation: new identity succeeds → stale metadata or identity-specific policy more likely, not proven. Same development-team requirement recurs → broader signing/service policy more likely, not proven. Different failure → investigate only that specific error. Other BTM attribution inputs and the retained plist filename mean this is not a clean-system experiment. A successful test does not establish a safe production migration.

**Next action:** request explicit approval for the manual live test above. No installation, service mutation, configuration change, source/project change, security-policy change, DMG, commit, push, or Step 8C work was performed. Only STEP8B-3.md was added to the repository.
