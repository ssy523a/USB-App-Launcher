# Step 5B — Shared automation in the independent Helper

Implemented and verified on 2026-10-22. No LaunchAgent, SMAppService, login startup, IPC, or live configuration synchronization is included.

## Files and architecture

- `USB App Launcher/AutomationLease.swift`: shared cross-process exclusive automation lease.
- `USB App Launcher/ApplicationAutomationService.swift`: acquires the lease before accepting state updates; retains it until outstanding launch requests settle during shutdown. Reports changed warnings to the console. Existing launch, ownership, shared-demand, and two-second Auto-Quit policies remain authoritative.
- `USB App Launcher/USBMonitorViewModel.swift`: explicitly starts the automation service and awaits shutdown. A failed lease acquisition leaves settings and USB observation available, with the existing warning presentation, but automation inactive.
- `USB App Launcher/USBRegistrationStore.swift`: optional strict missing-file handling for the Helper. The management app retains its existing missing-file behavior.
- `USBAppLauncherHelper/HelperAutomationController.swift`: loads one validated snapshot, starts USB monitoring, resolves exact VID/PID connection state, and forwards snapshots to the shared automation service.
- `USBAppLauncherHelper/main.swift`: explicit opt-in mode, main-thread Core Foundation run loop, SIGINT/SIGTERM cleanup.
- `USBAppLauncherHelper/Shared/`: seven relative symbolic links to the authoritative USBDevice, USBDeviceMonitor, RegisteredUSBDevice, SelectedApplication, USBRegistrationStore, ApplicationAutomationService, and AutomationLease sources. Xcode's synchronized Helper folder compiles these sources into the Helper target. Preserve these links when copying/checking out the project; they are not duplicate source implementations.

Both existing targets remain. No project build-setting or embedding changes were required. USBDeviceMonitor.swift, settings views, icons, persistent schema, sandbox settings, and the JSON location are unchanged. Shared runtime code uses AppKit for NSWorkspace/NSRunningApplication, but does not instantiate NSApplication or import SwiftUI views into the Helper.

## Startup and modes

The management app remains the default automation host. The Helper with no arguments stays inactive, as in Step 5A. It does not acquire the automation lease or start USB monitoring.

To enable a controlled Helper test:

1. Quit the management app, including other installed/debug copies.
2. Select the `USBAppLauncherHelper` Xcode scheme.
3. Edit Scheme → Run → Arguments; add and check `--automation-test` under Arguments Passed On Launch.
4. Run with Command + R. Expect ownership acquisition, the loaded rule count, and USB monitoring startup in the console.
5. Stop the Helper before returning to management-app automation. Uncheck/remove the argument and select the `USB App Launcher` scheme.

The checked scheme argument is only an opt-in request, never proof of ownership. No runtime enable switch is persisted in Application Support, and neither application starts the other. There is no new production UI toggle.

Helper startup order is lease acquisition → strict registration read/validation → subscribe to monitor snapshots → monitor startup/initial enumeration → shared policy evaluation. A missing, malformed, unreadable, or unsupported configuration disables automation, logs the failure, and releases the lease. It is not replaced or repaired.

## Exclusive automation ownership

Both processes use a nonblocking `flock(LOCK_EX | LOCK_NB)` on:

`~/Library/Application Support/USB App Launcher/automation.lock`

Only the process holding the open descriptor may accept automation state updates. Failure is safe and one-shot: there are no automatic retries or takeover. Restart the desired host after stopping the other one. The lock file is not a stored enabled/disabled flag; kernel lock state determines ownership. Never delete or replace this file while either host runs, because a replacement inode would create a different lock domain.

The descriptor uses close-on-exec, rejects a final-component symlink, and checks regular-file type, ownership, and link count. Acquisition runs off the main actor. The kernel releases the lease on descriptor close or process death, including Xcode's abrupt Stop. A stale file is harmless. This is cooperative exclusion between updated versions of these targets, not a security boundary against a hostile same-user process; quit older builds that do not participate in this protocol.

On orderly stop, launch and quit work is cancelled, outstanding submitted launch callbacks are awaited, and then the lease is released. An already-submitted operating-system launch cannot be retracted. Abrupt process termination also cannot retract a submitted LaunchServices request; the surviving/restarted engine still applies the existing running-instance and conservative ownership checks. Runtime ownership is never handed over or persisted.

## Configuration and policies

The Helper reads only:

`~/Library/Application Support/USB App Launcher/registered-devices.json`

It uses the existing store/decoder, preserves schema versions 1–2, and never calls save. Connection state, PIDs, and launch ownership remain runtime-only. Existing sandbox backups are untouched.

Configuration is a startup snapshot. Settings edits while the Helper runs do not change its snapshot. For Step 5B, stop the Helper before editing rules, then restart it to apply them. In particular, changing Auto-Quit in the management app while the Helper owns automation does not cancel the Helper's snapshot rule. Safe live updates belong to Step 5C.

The shared service retains exact instance ownership checks, protects pre-existing applications, does not relaunch after a manual quit without another qualifying connection, and treats a model as connected while any matching VID/PID connection remains. Shared application demand prevents quitting while another model needs the app. Conflicting Auto-Quit preferences retain the existing conservative veto policy. The cancellable two-second delay is a one-shot asynchronous delay, not polling. Only normal NSRunningApplication termination is used.

## Lifecycle and resource use

A single unsignalled CFRunLoop source keeps the actual main thread alive for asynchronous workspace callbacks. Dispatch signal sources handle SIGTERM and SIGINT. There are no periodic scans, repeating timers, recurring sleeps, or busy loops. Shutdown cancels automation work, stops the USB monitor, releases notification resources and the lease, cancels signal sources, and exits. It does not quit user applications merely because the Helper exits. Xcode Stop need not run cleanup callbacks.

Two idle `ps` observations of the automation-enabled Helper, at elapsed 2:15 and 2:29, reported 0.0% CPU and RSS 9,408 / 9,360 KiB (approximately 9.19 / 9.14 MiB). These are short-run observations, not a long-duration leak or energy assessment, and are not directly comparable to Step 5A's earlier measurement conditions. Check Activity Monitor over a longer physical USB test for CPU, memory growth, and idle logging.

## Executed verification

| Check | Result |
| --- | --- |
| Independent Helper Debug build | Passed using Xcode BuildProject |
| Main application Debug build | Passed using Xcode BuildProject; Helper built and embedded |
| Swift compiler diagnostics | No remaining errors or warnings |
| Build-tool warning | Main build: App Intents metadata extraction skipped because there is no AppIntents.framework dependency; no App Intents functionality is used |
| Default Helper scheme run | Passed: startup and Inactive Mode messages; Xcode Stop terminated it |
| Explicit Helper automation run | Passed: acquired lease, loaded 1 existing rule, started USB monitoring |
| Main first, Helper second | Passed: Helper logged ownership rejection and did not start USB monitoring |
| Helper first, main second | Passed: main logged ownership rejection while retaining USB observation |
| Release/reacquisition | Passed: subsequent host acquired after the previous host exited, including after Xcode Stop |
| SIGINT orderly shutdown | Passed: Shutdown requested → USB Monitoring stopped → Stopped; exit status 0 |
| SIGTERM | Sent to the specific test Helper; process exited and later acquisition succeeded; final console output was not captured for this run |
| Strict store loading | Xcode snippet using disposable files: missing rejected without creation; malformed rejected without replacement; valid empty version-2 list accepted |
| Existing configuration preservation | SHA-256 unchanged before/after runtime checks |
| Main app runtime smoke check | Launched successfully; acquired ownership and started USB monitoring in normal mode |
| Bundle duplication | Exactly one Helper executable inside the built app |
| Code signing | `codesign --verify --strict --verbose=2` passed for standalone Helper, embedded Helper, and containing app |

The Helper executable is at:

`USB App Launcher.app/Contents/Helpers/USBAppLauncherHelper`

Its executable permission is present. Existing automatic Apple Development signing and Code Sign On Copy are preserved. The Helper signing identifier remains `devplaceholder.VC4RZVAC.USB-App-Launcher.USBAppLauncherHelper`; the main identifier is unchanged. Debug products were verified; Release/archive/notarization were not exercised in this step.

## Remaining manual checks

Physical USB interaction and target-application launch/quit behavior were not automated. Do not treat the following as passed:

1. In normal management mode, verify registration editing/persistence, Dock icon, unchanged settings, and CTL-472 → MockTab launch/Auto-Quit regression.
2. Quit the management app. Enable Helper test mode. Confirm no Helper window, Dock icon, or menu-bar icon; connect CTL-472 and verify exactly one MockTab launch.
3. Disconnect: verify graceful Auto-Quit after two seconds only for the Helper-owned instance. Reconnect within two seconds: verify cancellation.
4. Start MockTab manually before connecting: verify no ownership and no Auto-Quit. Manually quit a Helper-launched instance while connected: verify no restart until a new qualifying connection.
5. Use two configured device models targeting the same app: verify one disconnect cannot quit while the other remains connected. Include conflicting Auto-Quit preferences.
6. Exercise rapid disconnect during launch, missing application references, and repeated connect/disconnect. Check for duplicates, crashes, and stale termination requests.
7. Stop the Helper while an automation-launched application is running: verify the user application stays open and no Helper process remains. Repeat with normal SIGTERM and Xcode Stop.
8. Observe Activity Monitor over an extended idle and USB cycling session. Do not assume short-run RSS observations prove absence of leaks.

Development execution must occur in the logged-in user's GUI session. An initial command-tool sandbox run could not establish access; it was not counted as a product failure or mutual-exclusion pass. The successful Helper executions used the normal user GUI session, without administrator privileges, Accessibility permission, or Full Disk Access.

## Step 5C preparation (not implemented)

Define safe live configuration delivery and ownership transition semantics before adding them. Keep a single configuration writer, preserve the lease across transitions, and avoid relying on atomic file replacement alone for interprocess coordination. No LaunchAgent, registration, login startup, or automatic Helper launch was added. No commit or push was performed.
