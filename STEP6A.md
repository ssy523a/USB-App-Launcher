# Step 6A — SMAppService LaunchAgent registration

Implemented 2026-10-23. Registration and unregistration were deliberately NOT executed during automated verification. They require user action through the UI. Step 6B responsibility handoff is not implemented.

## Files and bundle integration

- `com.ssy523a.USBAppLauncher.Helper.plist`: plist added to the Xcode navigator by the user for the dedicated Copy Files phase. The identical earlier prepared copy in `LaunchAgents/` is retained; it is not separately embedded.
- `USB App Launcher/HelperRegistrationManager.swift`: new observable main-actor manager, status mapping, serialized ServiceManagement backend actor, error reporting, and button eligibility.
- `USB App Launcher/ContentView.swift`: replaces the disabled Helper placeholder with registration status, action buttons, approval guidance, and an unregistration confirmation.
- `USBAppLauncherHelper/main.swift`: supports production `--automation-service` alongside `--automation-test`, using a single shared controller startup branch.
- `STEP6A.md`: implementation and verification record.

The user's Copy Files phases remain unchanged: executable to Wrapper / `Contents/Helpers` with Code Sign On Copy; plist to Wrapper / `Contents/Library/LaunchAgents` without Code Sign On Copy. Both copy during ordinary builds. The plist is sealed by the containing app signature. No direct project.pbxproj edits were made by the assistant.

Exactly one plist and one Helper were found in both Debug and Release bundles:

```
USB App Launcher.app/Contents/Library/LaunchAgents/com.ssy523a.USBAppLauncher.Helper.plist
USB App Launcher.app/Contents/Helpers/USBAppLauncherHelper
```

## LaunchAgent definition

| Key | Value |
| --- | --- |
| Label | `com.ssy523a.USBAppLauncher.Helper` |
| BundleProgram | `Contents/Helpers/USBAppLauncherHelper` |
| ProgramArguments | `USBAppLauncherHelper`, `--automation-service` |
| RunAtLoad | true |
| LimitLoadToSessionType | Aqua |
| KeepAlive / periodic schedules | Absent |

Before selecting the label, read-only queries found no matching loaded service in the current GUI, user, or system domain; 924 standard LaunchAgent/LaunchDaemon plists contained no matching label. This is a local conflict check, not a global reservation.

BundleProgram is relative to the containing app bundle and is supported for SMAppService-installed services. No shell script, absolute developer path, LaunchDaemon, privileged execution, or manually installed plist is used. Registration governs automatic startup; opening the management app does not register or launch a Helper.

## Registration architecture

The manager uses `SMAppService.agent(plistName: "com.ssy523a.USBAppLauncher.Helper.plist")`. A backend actor serializes framework calls away from the main actor; observable UI updates occur on the main actor. One shared manager prevents duplicate operations across windows. Busy operations disable both buttons.

Status is read on view appearance, when the scene becomes active (including return from System Settings), and after each operation. There are no polling timers or process-name searches. Status reflects registration/authorization, never verified process liveness.

| Status | Register | Unregister | Meaning |
| --- | --- | --- | --- |
| Checking / operation in progress | Disabled | Disabled | Await current state/operation |
| Not Registered | Enabled if bundled files are available | Disabled | Registration can be requested |
| Enabled | Disabled | Enabled | Registered and eligible, not necessarily running or automation owner |
| Requires Approval | Disabled | Enabled | Approval guidance and Open Login Items Settings button |
| Not Found | Enabled if bundled files are available | Disabled | Framework cannot find service; explicit registration can be attempted |
| Unknown future status | Disabled | Disabled | No unsupported assumption or automatic action |

The actual initial framework status during verification was **Not Found**, even with verified bundle contents. Therefore this state permits an explicit Register attempt when the plist is readable and Helper executable is present. The UI does not invent a Not Registered or Enabled result. Native API failures remain visible. Missing bundle components require rebuilding/reopening the complete app.

Register calls the native registration API only in response to the button. Successful return does not display Running. Errors are displayed, then actual status is read again, including a possible Requires Approval result. No failure resets configuration or synthesizes registration success.

Approval uses `SMAppService.openSystemSettingsLoginItems()` only when the user clicks the settings button. The user must allow the background item; the app never bypasses consent. Return to the app to refresh status. System Settings wording may vary with macOS release.

## Unregistration and process lifetime

Unregister presents a confirmation explaining that USB automation may stop, configuration remains, and no automatic takeover occurs. Cancel performs no operation.

The confirmed action uses the asynchronous `SMAppService.unregister()` overload (the Swift counterpart of `unregisterWithCompletionHandler:`). Apple's installed SDK documents completion after the managed running service has stopped, at which point it is safe to re-register. This deliberately avoids the synchronous unregister variant, which can return before process teardown.

The success message attributes stopping to ServiceManagement and explicitly excludes independently launched Xcode Helpers. No independent PID/liveness protocol exists in Step 6A. The app does not infer that every Helper process is gone merely from registration status, scan names, or send termination signals. If an independently started development Helper remains, stop that exact debugging session in Xcode. If an apparently system-managed instance remains despite API completion, report it and investigate before re-registering; no forceful recovery is implemented.

The Helper's existing shutdown code cancels work and leaves configured user applications running. macOS controls registered-service termination, so orderly callbacks are not guaranteed on every teardown. Runtime ownership is not persisted and the kernel releases the automation lease on exit.

## Production mode and exclusive ownership

`--automation-service` requests the same Step 5C controller as `--automation-test`: acquire the kernel lease, read the existing validated rules, start IOKit observation and live JSON watching, and apply the existing shared policies. Supplying both flags still creates only one controller, with service mode taking precedence. No flag leaves the Helper inactive as before.

If the management app already owns automation when Register is clicked, the new Helper must fail lease acquisition and remain inactive. It does not steal ownership or retry. Closing the management app later does not wake that inactive Helper into ownership. The Enabled label therefore cannot be interpreted as active automation. This development fallback is explicitly described in the UI and is not the final release handoff behavior.

A fresh Helper start with the lease available can own automation; a management app opened afterward remains configuration/monitoring-only. No automatic fallback reacquisition, service restart loop, or process termination was added. Final responsibility transition and login-session testing belong to Step 6B.

## Executed verification

| Check | Result |
| --- | --- |
| Initial bundle inspection before implementation | Correct plist and executable paths, no duplicate copies |
| Main Debug build | Passed using Xcode BuildProject |
| Independent Helper Debug build | Passed using Xcode BuildProject |
| Release main + dependent Helper build | Passed in `/tmp/USB-Step6A-Release` using unchanged Release settings |
| Plist syntax, Debug and Release | `plutil -lint` passed |
| BundleProgram resolution | Resolves to executable Helper in each bundle |
| Embedding, both configurations | Exactly one intended plist and one Helper |
| Signatures, both configurations | Strict codesign verification passed for app, embedded Helper, and standalone Helper |
| Read-only initial status/UI eligibility | Not Found; bundled files true; Register true; Unregister false |
| Production-mode direct execution | Acquired available lease, loaded 2 existing rules, started monitoring; normal SIGTERM cleanup exited 0 |
| Production-mode contention | After main app confirmed ownership, Helper rejected ownership and stayed inactive; SIGINT cleanup exited 0 |
| Actual JSON preservation | SHA-256 unchanged |
| Registration/unregistration/approval | NOT run; reserved for user-initiated manual testing |
| Hardware automation regression | NOT run in this step |

A compile-time naming collision with the existing `RegistrationStatus` view was corrected by naming the new enum `HelperRegistrationStatus`. No remaining Swift compiler warnings were found. Debug and Release emit the existing build-tool warning: App Intents metadata extraction skipped because no AppIntents.framework dependency exists.

The Step 5D `sandbox_extension_consume failed: 22` diagnostic remains observable during management startup. Prior investigation isolated it to one stored bookmark, with successful path/bundle/icon access and no demonstrated functional failure. No bookmark bytes, serialization, sandbox settings, entitlements, permissions, or registrations were changed to suppress it.

## Manual testing — explicit user actions only

1. Use one stable app copy and stop independent Xcode Helpers before service tests. Build/run the management app. Confirm registration status and absence of automatic registration. Do not move or delete an app copy while its service is registered; unregister from that copy first.
2. Click Register. Expect Enabled, Requires Approval with guidance, or a useful native error. Do not equate Enabled with Running. If approval is needed, click Open Login Items Settings, approve the item, and return to check updated status.
3. Verify existing USB settings, registrations, application selection, Auto-Quit values, and connection display remain intact. The main app's current automation ownership may keep the registered Helper inactive, by design.
4. Click Unregister, then Cancel: nothing should change. Repeat and confirm: both buttons should disable until completion; status should refresh. Configured user applications and device registrations must remain intact.
5. Register again only after unregistration completes. Check status and errors for duplicate-service issues. Do not run multiple app copies with this same service label.
6. Test System Settings approval/revocation and return to the app. Verify status changes without a polling loop. Failure should preserve settings and leave actual status visible.
7. Verify CTL-472/MockTab behavior under the actual automation owner: one launch, graceful Auto-Quit, reconnect cancellation, and protection for pre-existing apps. Do not expect an inactive Helper to acquire ownership later without a new start.
8. Confirm Light/Dark appearance, window resizing, approval/error text, normal Dock behavior, and Command + Q. Closing the management app must not unregister the service.

No automated login/logout/reboot tests were performed. Do not use those as an implicit workaround for Step 6A's handoff limitation; validate the final production transition in Step 6B.

## Scope preserved

USBDeviceMonitor, exact VID/PID matching, registration persistence, live configuration synchronization, ownership checks, shared demand, grace period, app icon, Bundle Identifier, sandbox configuration, and bookmark serialization remain unchanged. No system registration mutation, Step 6B work, commit, or push was performed by the assistant.
