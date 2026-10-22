# Step 5A — Independent Helper foundation

## Status

The independent Helper and Debug bundle integration are verified. On 2026-10-22,
the main application build succeeded with an explicit dependency on the Helper.
The executable is present exactly once at the intended bundle location and both
its signature and the containing app's signature pass strict verification.
The earlier embedding blocker is resolved by the manually configured build phases.
Release/archive validation and physical USB regression testing remain unperformed.

## New target and file

- Target/scheme: `USBAppLauncherHelper`, macOS Command Line Tool, Swift.
- Source: `USBAppLauncherHelper/main.swift`.
- Deployment target: macOS 14.0.
- App Sandbox: disabled; no sandbox entitlements were added. This also avoids
  introducing restrictions on the future graceful-termination implementation.
- `SKIP_INSTALL = YES` prevents a separate top-level Helper product in archives.
- Signing: automatic Apple Development signing with the existing team
  `X3P895EA4K`. Explicit signing identifier:
  `devplaceholder.VC4RZVAC.USB-App-Launcher.USBAppLauncherHelper`.
- The main application's identifier is unchanged.

## Lifecycle

Only Darwin and Dispatch are imported. Two DispatchSourceSignal objects monitor
SIGTERM and SIGINT on the main dispatch queue. Their default signal actions are
ignored so the dispatch handlers can perform cleanup. `dispatchMain()` keeps the
process alive while the OS waits for events; there are no polling loops, timers,
recurring sleeps, explicit worker threads, USB monitoring, or configuration I/O.

Shutdown is idempotent. Both sources are cancelled and released; a DispatchGroup
notification waits asynchronously for cancellation handlers before exiting with
status 0. Debug builds print startup, shutdown-request, and stopped messages.
Release builds do not emit these diagnostics. There is no AppKit/SwiftUI or UI
initialization, so the executable does not create windows, Dock icons, or menu
bar items. Xcode Stop can forcibly stop the process and is not guaranteed to run
the orderly cleanup handlers; SIGKILL cannot be handled.

## Verified bundle integration in Xcode

Verified location in the Debug application:

`USB App Launcher.app/Contents/Helpers/USBAppLauncherHelper`

This standard nested-helper location keeps executable code out of Resources and
can later be referenced relative to the app bundle by BundleProgram. No agent
plist or registration is created in Step 5A.

The main target now explicitly depends on USBAppLauncherHelper and has a Copy
Files phase targeting Wrapper / Contents/Helpers with Code Sign On Copy enabled.
Copy only when installing is disabled, as configured by the user. The build log
shows the explicit dependency, a single Helper copy operation into Contents/Helpers,
and signing of that nested executable before the outer app is signed.

Verification found exactly one USBAppLauncherHelper in the app bundle, at the
path above, with permissions 0755. No duplicate-copy or multiple-producer build
issues were found. Strict code-sign verification passed separately for the Helper
and app, and deep strict verification passed for the app and nested code. Both
are signed by Apple Development: SE YOUNG SEO (MJ23CHAN6P), team X3P895EA4K.
The standalone build product alongside the app is normal; it is not another
embedded copy. Release/archive behavior has not yet been checked.

## Running and verification

Select **USBAppLauncherHelper → My Mac**, then Command + R. The console should
print `[Helper] USB App Launcher Helper started` once and remain quiet while
idle. Stop with Xcode and verify the process disappears from Activity Monitor.
For an orderly shutdown, use Activity Monitor's **Quit** action (not Force Quit),
or interrupt a directly launched terminal instance with Control-C.

Completed checks:

- Main application and independent Helper Debug builds succeeded.
- Xcode Issue Navigator reported no warnings/errors.
- Helper scheme launched successfully under Xcode's debugger.
- Startup message appeared exactly once.
- Two `ps` samples at process ages 33 and 39 seconds both measured 0.0% CPU,
  10,880 KiB RSS (approximately 10.6 MiB), and 0.01 seconds cumulative CPU time.
  This is a short sample under debugging, not a long-duration leak proof or an
  Activity Monitor physical-footprint measurement.
- Xcode Stop removed the observed process; no orphan remained.
- Independent SIGTERM and SIGINT runs each printed orderly cleanup messages
  and exited with status 0.
- `codesign --verify --strict` passed for the standalone executable; its signing
  identifier and Apple Development team were verified.
- Resumed main-app Debug build succeeded with a two-target dependency graph.
- Exactly one Helper is embedded at Contents/Helpers/USBAppLauncherHelper (0755).
- Embedded Helper and app passed codesign --verify --strict; the app also passed
  codesign --verify --deep --strict. No duplicate embedding/build-phase issues found.
- The resumed build log includes an App Intents tooling warning:
  “Metadata extraction skipped, no AppIntents.framework dependency found”.
  This is not a Swift compiler warning; no App Intents functionality is used.
  No compilation errors were reported.

In Activity Monitor, filter by USBAppLauncherHelper, inspect CPU and Memory over
several minutes, and confirm memory does not grow continuously. Debugger/runtime
overhead and memory accounting differ from standalone Release measurements.

The main scheme was restored after testing. Main source files, USB monitoring,
automation policies, settings UI, custom icon, storage, and registrations were
not changed by this step. The prior application-icon size edit was already in
the working tree and was preserved. Physical CTL-472/MockTab regression testing
has not been repeated during this step.

## Later steps

The Helper does not start automatically and performs no USB or application work.
The settings UI still shows unavailable, disabled Helper controls. Step 5B/5C
must separately address sharing reusable services/configuration and preventing
dual automation ownership. Step 6 registration remains out of scope. No
LaunchAgent, launchctl operation, SMAppService, privileged operation, commit, or
push was added.
