# Step 6B — Helper-only application automation

Implemented 2026-10-23. Login startup is configured and statically validated; an actual logout/login test remains manual. No registration, unregistration, logout, reboot, or system-setting changes were performed during this step.

## Changed files and responsibilities

- `USB App Launcher/USBMonitorViewModel.swift`: removed the ApplicationAutomationService instance and all start, update, edit-protection, and shutdown calls to it. The view model now loads/saves settings, handles application selection, and observes USB devices for display only.
- `USB App Launcher/ContentView.swift`: removed the former management automation-warning binding and Step 6A fallback message. The Helper section now explains the final responsibility split; the unregistration confirmation states that this app performs no application automation.
- `STEP6B.md`: verification and manual testing record.

No Helper source, automation policy, USB monitor, registration manager, watcher, persistent model, plist, signing setting, bookmark serialization, or Xcode scheme was changed. Shared automation source remains available in the existing target layout, but only HelperAutomationController instantiates ApplicationAutomationService. There is no management execution path into its lease acquisition, application launching, or application termination methods.

The management app remains a normal Dock app with the existing icon and settings table. Its application picker selects configuration; it does not launch the selected application. Management shutdown only finishes its pending persistence and stops its own USB observation. Opening or closing the management app cannot start/stop the independent Helper or take automation ownership.

## Helper lifecycle and ownership

Both `--automation-service` and `--automation-test` continue to use the existing Step 5C controller. Startup acquires the exclusive lease, loads validated settings, starts initial USB enumeration, and observes USB and configuration events. The main-thread event loop has no polling, recurring sleeps, or timers.

The kernel-held nonblocking flock remains in `~/Library/Application Support/USB App Launcher/automation.lock`. Competing production/debug Helper instances must acquire the same lease. Rejected Helpers remain safely inactive without retries. Normal shutdown cancels pending automation, stops observation, and releases resources; process death also releases the kernel lock. Runtime application ownership is never persisted or transferred to a replacement process. An already-running application remains protected when a new Helper starts.

Shutdown does not terminate configured applications merely because the Helper exits. Already-submitted macOS launch/termination requests cannot be recalled, and abrupt termination may bypass orderly cleanup. Existing conservative instance checks remain unchanged.

With no Helper running, USB connection changes only affect the management table. Unregistered production service means no automatic service startup; a deliberately started development Helper is an explicit exception and must be stopped separately after debugging.

## Registration and login startup

The Step 6A SMAppService manager is unchanged. Register and confirmed Unregister are explicit user actions. Actual states remain Not Registered, Enabled, Requires Approval, Not Found, or an operation error; none is labeled Running. Enabled means eligible, not confirmed process liveness.

The asynchronous unregistration API waits for the managed process to stop before successful completion. It does not stop independent Xcode/direct Helpers. If a Helper unexpectedly remains, identify whether it belongs to a development session; stop that exact session normally. Investigate an unexpected managed instance instead of force-stopping it or assuming automation has ended. The management app cannot resume automation as a fallback.

Unchanged bundle configuration:

| Item | Value |
| --- | --- |
| Label | `com.ssy523a.USBAppLauncher.Helper` |
| Plist | `Contents/Library/LaunchAgents/com.ssy523a.USBAppLauncher.Helper.plist` |
| BundleProgram | `Contents/Helpers/USBAppLauncherHelper` |
| Arguments | `USBAppLauncherHelper --automation-service` |
| RunAtLoad | true |
| Session | Aqua |
| KeepAlive / periodic schedule | Absent |

Use a stable app location before registering and avoid simultaneously registering different development/release copies under the same label. Do not move/delete a registered app copy; unregister it explicitly first. The user must approve background execution if macOS requests it.

The Helper reads Application Support using the logged-in user's home directory, not a working-directory-relative path. Direct execution from `/tmp` was verified without Xcode/debugger attachment. It has no dependency on an open Terminal or management process. A registered LaunchAgent is eligible to start in the GUI user session on login, but actual session startup must be verified manually below.

There is deliberately no unconditional KeepAlive or automatic restart policy. If the Helper exits unexpectedly, automation remains unavailable until an appropriate new service start. A future recovery policy would require separate design/review; it was not added silently.

## Configuration and safety

The sole configuration file remains `~/Library/Application Support/USB App Launcher/registered-devices.json`. The management app writes using the existing actor-isolated atomic store. The Helper's directory/file DispatchSources reload complete validated snapshots in order. Invalid/missing data retains the last valid rules; a valid empty list is distinct. No Helper writes or persistent runtime ownership were added.

Rule deletion/reassignment protection, shared demand, exact VID/PID matching, composite deduplication, two-second disconnect grace period, existing-app protection, and graceful termination only remain unchanged. UI edits affect automation after successful persistence and Helper observation. The removed pre-save callbacks targeted only the now-removed local engine; no cross-process pre-save guarantee is introduced. Failed saves leave the Helper using its prior valid rules. Requests already sent before a reload cannot be recalled.

No live Helper diagnostic transport was added. Helper automation errors are logged by the Helper; registration status alone is not a health indicator. The management app no longer presents warnings from a nonexistent local automation service.

## Executed verification

| Check | Result |
| --- | --- |
| Main Debug build | Passed using Xcode BuildProject |
| Independent Helper Debug build | Passed using Xcode BuildProject |
| Release main and Helper | Passed in `/tmp/USB-Step6B-Release` |
| Bundle structure, both configurations | Exactly one Helper and one intended LaunchAgent plist; BundleProgram resolves correctly |
| Signatures, both configurations | App, standalone Helper, and embedded Helper passed strict codesign verification |
| Management-only startup | USB observation started; actual service status Not Registered; no automation ownership/launch logs |
| Source call-site inspection | Only HelperAutomationController constructs ApplicationAutomationService; no management calls into automation remain |
| Helper with management app open | Production mode acquired the lease and loaded 2 rules; USB monitoring started |
| Duplicate Helper | Debug mode was denied ownership while production mode owned it; no second monitoring/automation startup |
| Management reopened while Helper active | USB observation and Not Registered status only; no ownership attempt |
| Helper shutdown with management still open | Orderly SIGINT exit 0; independent nonblocking lock acquisition succeeded afterward, proving no fallback acquisition |
| Management normal quit | Requested via NSRunningApplication.terminate for the exact test PID; management process exited while Helper remained alive |
| Isolated Swift Testing suite | 3 tests passed: replacement/in-place changes, invalid/missing/recreated JSON, rapid ordered saves/no-op suppression, schema and transition policies |
| Actual configuration | SHA-256 unchanged |
| Service registration/unregistration | Not executed; user reported Step 6A testing and current unregistered state |
| Hardware and actual login startup | Not performed; manual checks below |

The tests use authoritative sources with temporary JSON fixtures. No real registration edits were used to simulate configuration changes. Run them with `python3 Verification/Step5C/run.py`.

No Swift compiler warnings remain. Debug and Release retain the build-tool warning that App Intents metadata extraction was skipped because no AppIntents.framework dependency exists. The known `sandbox_extension_consume failed: 22` diagnostic appeared during management startup; Step 5D found no demonstrated functional failure. No bookmark or entitlement workaround was applied.

Idle samples of the directly started production-mode Helper showed 0.0% CPU, with RSS 8,416 KiB at 0:16 9,472 KiB at 1:06, and 9,456 KiB at 3:01 (approximately 8.22 → 9.25 → 9.23 MiB). These short observations include startup settling and are not a long-duration leak assessment. Continue Activity Monitor observation during the manual tests.

## Manual verification checklist

1. **Unregistered:** stop any independent debugging Helpers; confirm Not Registered in the app. Connect CTL-472/CTL-672. The row must update, but MockTab must not launch. Repeat with Auto-Quit checked; the management app must not terminate MockTab on disconnect.
2. **Register:** choose one stable app copy, click Register, approve background activity if requested, and return to the app. Check Activity Monitor for the Helper and perform a functional USB test. Enabled alone is not proof of a working instance. A device already connected at Helper startup should trigger the existing initial-enumeration behavior.
3. **Auto-Quit:** allow the Helper to launch MockTab, then disconnect. Expect normal termination after two seconds if all ownership/shared-demand conditions permit. Reconnect inside two seconds to verify cancellation. Start MockTab manually before connecting and confirm it is protected.
4. **Management closed:** use Command + Q. Connect/disconnect again and verify continued Helper automation. Reopen the app and verify settings/connection state with no duplicate launch or ownership attempt.
5. **Live edits:** change app selection, Auto-Quit, add/remove rules while the Helper runs. Confirm changes without restart; deletion/reassignment must not itself quit the old app. Test two models sharing MockTab and conflicting Auto-Quit settings. Test manual target-app quit protection.
6. **User login:** save all work first. Only at your explicit decision, log out and log back in with the service registered and approved. Do not open the management app. Confirm the Helper starts and USB automation works with exactly one active owner. This session test has not been automated or reported as passed.
7. **Unregister:** confirm Unregister, wait for completion, and check the managed Helper has exited. Reconnect/disconnect with the management app open: no automation should resume. Preferences and already-running user applications must remain intact. Report any unexpected remaining managed instance.
8. **Debug conflict:** normally unregister production before independent debugging. For the deliberate conflict test only, run the Debug Helper with `--automation-test` while the production instance owns automation. Expect rejection and no competing requests. Stop the Debug session afterward. No automatic takeover occurs when the first owner exits.
9. **Resources/recovery:** observe CPU and memory over extended idle/USB cycling. Check that unexpected Helper exit is visible through lost functionality/logs rather than falsely assuming Enabled guarantees operation; no restart policy exists yet.

## Remaining work

Actual login startup, hardware regression, GUI edits under live automation, and service unregistration behavior under this final responsibility split remain manual acceptance checks. Step 7 (About window) and Step 8 (packaging/notarization) were not started. No registration changes, permissions, App Sandbox changes, migration, commit, or push were performed.
