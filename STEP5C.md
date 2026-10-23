# Step 5C — Live configuration synchronization

Implemented on 2026-10-23. This supersedes Step 5B's startup-only configuration limitation. The Helper remains explicitly opt-in through `--automation-test`; no automatic startup, LaunchAgent, SMAppService, installation, or Step 6 functionality was added.

## Modified files

| File | Responsibility |
| --- | --- |
| `USBAppLauncherHelper/ConfigurationWatcher.swift` (new) | Event-driven directory/file observation, serial disk reads and validation, ordered snapshots, descriptor cleanup |
| `USBAppLauncherHelper/HelperAutomationController.swift` | Reconciles live rules with the latest USB snapshot on the main actor; joins concurrent shutdown requests |
| `USB App Launcher/USBRegistrationStore.swift` | Exposes the existing default URL and one shared transactional decoder; existing writer remains actor-isolated and atomic |
| `USB App Launcher/ApplicationAutomationService.swift` | Initializes changed application selections while connected; arms Auto-Quit only with connected demand and unanimous consent; retains edit/ownership protections |
| `USB App Launcher/USBMonitorViewModel.swift` | Updates application-selection explanatory text to match live behavior |
| `Verification/Step5C/ConfigurationTests.swift` and `run.py` (new) | Isolated Swift Testing verification using authoritative sources and temporary JSON files |

The existing shared-source symlinks continue to supply the same store and automation implementation to both targets. No target membership, bundle identifiers, icons, entitlements, or project settings changed. `USBDeviceMonitor.swift`, `AutomationLease.swift`, settings views, the disabled Helper section, and persistent models are unchanged.

## Synchronization architecture

The authoritative configuration remains:

`~/Library/Application Support/USB App Launcher/registered-devices.json`

The management app is the writer. The Helper only reads. There is no second store, database, migration, or persisted runtime state.

After acquiring the existing exclusive automation lease, the Helper creates a `ConfigurationWatcher`. A serial utility dispatch queue owns all watcher state and file operations. A directory DispatchSource observes writes, rename, deletion, attributes, and revocation. A complementary file source detects in-place writes. The directory source survives atomic replacement of the JSON inode; the file source is reopened by pathname on events. Observation is armed before the initial read, eliminating the load-before-watch gap.

This uses documented [DispatchSourceFileSystemObject](https://developer.apple.com/documentation/dispatch/dispatchsourcefilesystemobject) APIs. Descriptors are closed only in dispatch-source cancellation handlers, as required by [dispatch_source_set_cancel_handler](https://developer.apple.com/documentation/dispatch/dispatch_source_set_cancel_handler). No NSFilePresenter notification assumptions, distributed notification dependency, polling, periodic scans, or repeating timers are involved.

Each event reads the current complete file and invokes the same decoder/validation as the management store. Byte-identical content avoids decoding again; semantically equal rules avoid reconciliation. Serial reads yield an ordered AsyncStream; one main-actor consumer applies complete snapshots without overlapping reload tasks. USB events use the same main actor and always reconcile with the current accepted rules. An older snapshot is never applied after a newer accepted snapshot.

Filesystem notifications may coalesce rapid saves. The latest valid file is authoritative; every intermediate user edit is not guaranteed to produce a separate reload. There is no transactional acknowledgment to the settings app. A launch/termination request already submitted to macOS before a change is observed cannot be recalled. The normal two-second disconnection grace period remains unchanged.

## Invalid files and recovery

Missing, unreadable, malformed, or unsupported JSON produces an error event, never an empty array. The watcher does not write, delete, or repair it. If rules were loaded previously, the Helper retains and continues using that last valid snapshot. If startup has no valid snapshot, USB automation remains inactive until a valid snapshot arrives. A valid empty array is accepted and removes all rule demands without quitting applications solely because of removal.

The directory source observes JSON deletion/rename and later recreation. Recovery to the same previously valid rules is recognized, without unnecessarily reapplying identical rules. Errors are logged once per invalid interval; normal reload and rule-count messages are Debug-only and contain no personal paths.

If the entire Application Support subdirectory is renamed, removed, revoked, or cannot be watched, automation stops conservatively. It does not silently follow a new directory: replacing the directory also affects the lock-file inode used for exclusivity. Restore the directory and restart the desired host. Do not remove/replace `automation.lock` or its parent directory while an engine runs. Permission recovery without a filesystem event can also require a restart; there is deliberately no retry timer.

## Rule reconciliation and safety

| Change | Behavior |
| --- | --- |
| Add a rule for a connected model | Initializes demand; launches the selected application if appropriate |
| Delete a rule | Removes demand, cancels relevant pending work, and vetoes quitting the formerly selected owned application because of that edit |
| Change application selection | Protects the old application and initializes the new application immediately if connected; no new instance if it is already running |
| Enable Auto-Quit while connected | Arms a future qualifying disconnect, subject to ownership and all shared rules consenting |
| Enable Auto-Quit while disconnected | Does not arm or retroactively terminate an existing instance; waits for connected demand |
| Disable Auto-Quit | Disarms and cancels pending termination; a future enable can arm on connected demand |
| Conflicting shared-app preferences | Any disabled rule prevents Auto-Quit; any connected demand prevents termination |
| Invalid configuration | No partial application; last valid snapshot remains active |

Deletion/reassignment vetoes remain conservative for the affected owned instance, even if another rule later refers to it. A new launch epoch may establish fresh ownership. A manually terminated app is not relaunched merely by changing Auto-Quit. An actual application selection change is a new qualifying configuration action.

The management app's pre-save protection remains: unchecking Auto-Quit blocks pending quits while persistence is in flight; a failed save does not remove this protection. The Helper applies changes only after observing valid persistent data. The application-selection message now accurately describes immediate application of saved selections.

Actual NSRunningApplication instance identity, launch date, bundle identity, existing-app protection, single-instance launch configuration, graceful termination only, shared demand, and the two-second cancellable delay remain in the shared service. No ownership, PID, or connection state is persisted. No user application is terminated merely because an automation host exits.

## Responsibility and lifecycle

There is no automatic handoff or takeover. The Step 5B nonblocking kernel `flock` remains the sole automation ownership gate:

- Main first: management automation runs; a later Helper stays inactive.
- Helper first: Helper automation runs; the management app provides settings and USB connection status, and its writes are observed live by the Helper.
- Owner exits: its kernel lock is released, including after abrupt termination. An already-running rejected host does not retry. Restart the desired host to acquire ownership.

The existing inactive-host warning remains. It does not disable registration editing. Closing/quitting the management app does not stop the independent Helper.

Helper execution remains a UI-less main-thread run loop without NSApplication initialization. SIGINT/SIGTERM share orderly cleanup. Shutdown marks the controller stopped, cancels configuration/USB consumers and automation tasks, waits for outstanding launch callbacks, releases the lease, cancels filesystem sources and closes their descriptors, and stops the USB monitor. Concurrent error/signal cleanup paths await one shared shutdown task. Xcode Stop can be abrupt and need not execute cleanup logs.

## Automated and runtime verification

Tests were run on Apple Silicon using the installed Xcode toolchain and the project's Swift 5 language mode. No real registrations were edited during verification.

| Check | Result |
| --- | --- |
| Main application Debug build | Passed with Xcode BuildProject |
| Independent Helper Debug build | Passed with Xcode BuildProject |
| Swift compiler diagnostics | No remaining errors or warnings in the Xcode builds |
| Build-tool warning | Main app reports skipped App Intents metadata extraction because no AppIntents.framework is linked; no App Intents features are used |
| Isolated Swift Testing suite | 3 tests passed, 0 failures |
| Initial valid configuration and atomic replacement | Passed using the production watcher and decoder |
| In-place editing | Passed |
| Malformed file preservation and recovery | Passed; invalid bytes remained untouched; valid recovery recognized |
| Rename/disappearance/recreation and valid empty list | Passed |
| Missing startup configuration | Passed; reported invalid, not empty |
| Rapid atomic saves | Passed; observed revisions stayed ordered and reached the final revision |
| Identical save | Passed; no redundant rules event |
| Decoder compatibility | Version-1 defaults accepted; duplicates and unsupported versions rejected |
| Transition policy checks | Connected addition/reassignment, duplicate suppression, no retroactive Auto-Quit arming, and shared-demand/preferences passed |
| Real Helper startup | Acquired lease, loaded the existing 2 rules, started USB monitoring |
| Main-first exclusivity | Later Helper logged ownership rejection and did not start monitoring |
| Helper-first exclusivity | Later main app logged ownership rejection while retaining USB observation |
| Management process exit | Helper remained alive after Xcode stopped the management process |
| Orderly Helper shutdown | SIGINT produced Shutdown requested, Monitoring stopped, Stopped, and exit status 0 |
| Configuration preservation | Actual JSON SHA-256 unchanged before/after runtime verification |
| Embedding and signatures | Exactly one executable Helper in the app; standalone Helper, embedded Helper, and containing app passed strict codesign verification |

The runtime management-app console also emitted `sandbox_extension_consume failed: 22 (Invalid argument)`. Ownership and USB startup still completed. Its origin was not established in this step; sandbox settings were not changed. Verify selected-app icon/bookmark behavior during the manual GUI checklist and investigate if it causes an observable failure.

The isolated test package initially defaulted to Swift 6 mode and rejected an existing nonisolated AppKit observer deinitializer. The harness was corrected to match the existing project's Swift 5 language mode; the production language settings and observer implementation were not changed.

Bundled path remains:

`USB App Launcher.app/Contents/Helpers/USBAppLauncherHelper`

Debug builds and development signatures were checked; Release archives and notarization were not exercised.

### Resource observations

Automation-enabled Helper samples at elapsed 0:11, 1:19, and 2:15 reported 0.0% CPU. RSS was 8,384, 9,360, and 9,360 KiB respectively (approximately 8.19 → 9.14 → 9.14 MiB). No repeating console output was observed while idle. These short samples do not establish long-term leak freedom or cover sustained USB/configuration churn.

## Repeating verification

Run isolated tests from the repository root:

```sh
python3 Verification/Step5C/run.py
```

The runner creates a disposable Swift package with links to authoritative sources and uses Swift Testing. Temporary JSON fixtures and build artifacts are removed on exit. It never starts an automation service or changes the real configuration. The short delay and timeout in the tests are observation deadlines only, not production polling.

### Manual GUI and hardware checklist (not performed in this step)

1. Quit the management app. Choose `USBAppLauncherHelper` → Edit Scheme → Run → Arguments; enable `--automation-test`. Run and confirm ownership, configuration reload, and USB monitoring logs. Confirm no Helper window, Dock icon, or menu-bar icon.
2. Start the management app while the Helper owns automation. Confirm the normal settings UI, Dock icon, connection status, and disabled Helper registration buttons remain intact.
3. With CTL-472 connected, add a registration/select MockTab. Verify the Helper logs a reload without restarting and launches MockTab once. Do not mistake the management app's inactive-automation warning for a Helper failure.
4. Change the selected application while connected. Verify the new selection launches safely and the old application stays open. Check icons and application resolution, including the runtime diagnostic noted above.
5. Enable Auto-Quit while connected, then disconnect: verify graceful quit after two seconds only for a reliably Helper-owned instance. Reconnect within two seconds: verify cancellation.
6. Disable Auto-Quit during a pending delay: verify cancellation after the saved change is observed. Enable it while disconnected: verify no retroactive quit; reconnect then disconnect to qualify again.
7. Delete a rule while its app runs. Verify the app remains open. Test two different device models sharing one app and conflicting preferences.
8. Make several quick valid UI edits. Verify final Helper rules agree with settings and no duplicate application instances appear. Repeat missing-app, manually pre-running app, and manual-quit protections.
9. Quit the management app normally with Command + Q while the Helper runs. Verify continued physical USB automation. Restart the management app and verify persistence.
10. Stop the Helper during an Auto-Quit delay. Verify the target app stays open. The management app must not silently take over; restart it to restore fallback automation.
11. Repeat CTL-472/MockTab launch, quit, and rapid reconnection tests and observe Activity Monitor over an extended idle/cycling session. Hardware outcomes from earlier steps are not counted as Step 5C passes.

## Limitations and Step 6 preparation

Filesystem delivery is asynchronous, not an IPC acknowledgment protocol. The Helper reads the latest valid snapshot, not an audit history of every save. Invalid-file recovery intentionally retains old valid automation rules. Whole-directory replacement requires stopping and restarting the host. Use one management writer; atomic replacement does not prevent competing independent writers from losing edits. The management app does not live-import edits made by external tools.

Production responsibility handoff, explicit acknowledgments/status transport if needed, and service registration remain future work. The current safe behavior requires restarting a rejected host after the owner exits. No force-stop, takeover loop, periodic retry, LaunchAgent, SMAppService, login startup, or automatic Helper launch was added. No commit or push was performed.
