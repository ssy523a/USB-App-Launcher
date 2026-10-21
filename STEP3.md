# Step 3: application automation

## Migration and sandbox

The user confirmed that the version-1 registration file correctly contains zero
devices. Its copied contents were validated before any project settings changed.
The original sandbox file remains untouched at:

`~/Library/Containers/devplaceholder.VC4RZVAC.USB-App-Launcher/Data/Library/Application Support/USB App Launcher/registered-devices.json`

A byte-for-byte backup remains in `Migration Backups/` in this project. Migration
used a flushed temporary file in the destination directory, then an atomic
exclusive hard link to publish the complete file without replacing an existing
destination. The temporary link was removed afterward. Both bytes and decoded
JSON were verified at:

`~/Library/Application Support/USB App Launcher/registered-devices.json`

Verified SHA-256:
`c3dd0920ca8e598947e979767d99755dbb02002505f0db452ecf11be82854a1b`

After migration, `ENABLE_APP_SANDBOX` was set to `NO` for the target's Debug and
Release configurations using Xcode. This removes App Sandbox isolation, as
approved, because NSRunningApplication.terminate() cannot terminate other apps
from a sandboxed process. No administrator, Accessibility, Full Disk Access,
Apple Events, Helper, LaunchAgent, or login registration was added. The app
remains a normal Dock application. The USB monitor and custom icon are unchanged.

## Source files

- `SelectedApplication.swift`: selected bundle ID, exact path, display name, and
  bookmark; validates the app bundle and executable off the main actor.
- `ApplicationAutomationService.swift`: centralized main-actor launch ownership,
  model transitions, shared-app demand, cancellation, and graceful termination.
- `ApplicationSelectionCell.swift`: native selection button with app icon/name.
- `RegisteredUSBDevice.swift`: optional app selection and Auto-Quit preference;
  version-1 decoding defaults to no app and Auto-Quit disabled.
- `USBRegistrationStore.swift`: accepts schema versions 1 and 2; writes version 2
  atomically only when registration settings change.
- `USBMonitorViewModel.swift`: native NSOpenPanel selection, persistence, and
  forwarding live registered-device states to the automation service.
- `ContentView.swift` and `MyApp.swift`: expanded table and window width.

Connection status, PIDs, launch ownership, and pending tasks are never persisted.

## Behavior and conservative policies

Matching continues to use exact VID/PID. All physical connections of a model
must disappear before that model becomes disconnected. Initial enumeration can
launch a configured app once; duplicate connected snapshots do not launch again.
Manual app termination never causes an automatic restart until a later USB
disconnected-to-connected transition.

The selected URL is resolved and checked against its stored bundle identifier.
The service never searches for an arbitrary replacement copy by identifier.
Running apps are checked by bundle identifier, or exact URL when no identifier
exists. Existing instances are not owned. New ownership requires the actual
NSWorkspace return instance, a matching URL and identifier, and a non-nil launch
date at or after the request. Ownership is discarded when that instance exits;
quit checks verify the same instance, launch date, and identity again.

NSWorkspace launches asynchronously with activation and instance substitution
disabled. The app can still choose to show its own windows. No shell commands,
AppleScript, forceful termination, or process-name matching are used by the app.

Connected rules are counted centrally by application identity. Auto-Quit waits
two seconds using a cancellable Task.sleep, then rechecks current demand and
ownership. Reconnection cancels the delay. Only terminate() is called, once per
owned instance; an app may refuse or show an unsaved-document prompt. There is
no retry or escalation. A reconnect cannot retract a quit request already sent
after the grace period.

All registrations targeting an app must enable Auto-Quit, including disconnected
rules. Any opt-out vetoes termination. An opt-out or configuration edit also
protects the current owned session even if the user later re-enables Auto-Quit;
this conservative veto lasts until that app exits and a new owned session starts.
Different selected paths sharing a bundle ID are treated as ambiguous and block
launch/quit decisions until the selections agree.

Changing the app while a model is connected defers launch until the next
connection or management-app restart. Reassignment and deletion never quit the
old app. Pending destructive work is cancelled immediately on a user edit,
before persistence. A failed save leaves the prior registration intact and the
running app protected. Shutdown cancels tasks and relinquishes ownership without
terminating target apps. An OS launch request already submitted cannot be
retracted; if it finishes after cancellation the app remains unowned and running.

Because the app is now unsandboxed, selections use ordinary bookmarks, not
security-scoped grants. Any successful temporary security-scope access during
selection is balanced. Stale bookmarks, missing apps, changed bundle IDs, and
inaccessible executables require reselection and show a nonintrusive warning.
No automatic substitution occurs. Selecting an app again resets Auto-Quit off.

## Verification and limitations

The macOS Xcode build succeeded without compiler errors. Executable checks passed
for version-1 defaults, version-2 persistence, missing-app rejection, startup,
duplicate snapshots, reconnect transitions, connected selection changes,
shared-app demand, conflicting Auto-Quit preferences, and empty/deleted rules.
The original USB monitor and tracked icon assets have no changes.

A temporary fixture app failed to remain running, so the attempted end-to-end
ownership/grace-period check was inconclusive. The service refused ownership of
the exited instance. Physical USB and MockTab lifecycle behavior still require
manual verification. LaunchServices does not provide an exclusive launch
transaction against other launchers; very close external launches are inherently
race-sensitive. Missing/earlier launch timestamps result in no ownership and no
Auto-Quit. Normal termination is a request, not a guarantee of exit.

## Manual checks (Command + R)

1. Register CTL-472, select MockTab using its row, and enable Auto-Quit. Disconnect
   and reconnect the tablet. Expect one background launch and a Debug log.
2. Disconnect it. Expect one normal quit request after two seconds.
3. Reconnect within two seconds. Expect cancellation and the same running instance.
4. Start MockTab manually before connecting. Disconnect after connection; MockTab
   must remain running because it was not automation-owned.
5. Allow automation to launch MockTab, then quit MockTab manually. It must not
   relaunch while the tablet remains connected. Reconnect to allow another launch.
6. Restart USB App Launcher with the tablet and MockTab already running. Expect
   no duplicate and no ownership claim. With MockTab closed, startup may launch it.
7. Assign the same MockTab copy to CTL-472 and H3. Keep one model connected while
   disconnecting the other; MockTab must stay open. Verify the opt-out policy by
   disabling Auto-Quit on either rule.
8. Disconnect during launch, and also reconnect rapidly. Expect no duplicate or
   stale destructive operation; quit is considered only after launch completes.
9. Change the selected app while connected, delete a rule, and disable Auto-Quit
   during a pending grace period. The old app must remain running.
10. Quit USB App Launcher while a target is running, including during the grace
    period. The target must remain running.
11. Select an app that is later moved/removed and reconnect. Expect a warning or
    safely resolved bookmark, never an arbitrary replacement application.
12. Verify Light/Dark appearance, app icon/name, disabled Auto-Quit without a
    selection, persistence across relaunch, and unchanged USB registration/removal.

Step 4 is not implemented. No commit or push was performed.
