# Step 8B-2 — Single-Mac compatibility validation

**CONDITIONAL PASS: read-only artifact preflight passed; live compatibility tests NOT TESTED.** Updated 2026-10-24. No installation, registration, app execution, rebuild, re-signing, or system change was performed by the assistant.

## Preflight

Candidate: `/private/tmp/USB-Step8B-1-AdHoc-Pending-3_2ka65a/USB App Launcher.app`

- Candidate exists; main and Helper pass strict nested signature verification, both report ad-hoc signing and no Team Identifier. Identifiers are unchanged.
- Main entitlements contain only `com.apple.security.files.user-selected.read-only=true`; Helper entitlements are empty. No get-task-allow, Sandbox, or privileged entitlement. Hardened Runtime remains disabled.
- Exactly one Helper and one intended LaunchAgent plist. Label `com.ssy523a.USBAppLauncher.Helper`; BundleProgram `Contents/Helpers/USBAppLauncherHelper`; arguments `USBAppLauncherHelper`, `--automation-service`; RunAtLoad=true, Aqua session.
- `/Applications/USB App Launcher.app` does not currently exist.
- Read-only `launchctl print gui/501/com.ssy523a.USBAppLauncher.Helper` found no loaded service in that domain. **This does not prove SMAppService is unregistered.** Confirm actual registration status in the development app.
- Process enumeration failed with “sysmond service not found / Cannot get process list”. Helper count is **UNKNOWN**, not zero. Check Activity Monitor manually before installation; no equivalent retries performed.
- Configuration SHA-256 baseline: `38904fa2f66cf35a63e44f331a016c90fdb3819052d2b00b29e95b57b452adc3`. No configuration contents were changed.

## Manual sequence — pause and report at each checkpoint

1. **First action:** open the development copy used for earlier registration and read its Background Helper status. If registered, click Unregister and confirm. Report the resulting status or exact error. If already Not Registered, do not register it.
2. In Activity Monitor select All Processes and search `USBAppLauncherHelper`. Confirm no previous Helper remains. An Xcode test Helper must be stopped using its own Xcode session. If a production Helper unexpectedly remains, stop here and report; do not force-quit it.
3. Quit the development management app. If an installed app has appeared in /Applications since preflight, preserve it by copying it to a clearly named backup folder before replacement. Keep the original development build and all JSON/backups intact.
4. In Finder use Go → Go to Folder (Shift-Command-G), enter `/private/tmp/USB-Step8B-1-AdHoc-Pending-3_2ka65a/`. Copy USB App Launcher.app (Command-C), open Applications, and paste (Command-V). Launch the copy specifically from /Applications. Do not run the staging copy or Xcode for this test. Report launch success or exact warning.
5. If macOS blocks first launch, use System Settings → Privacy & Security → Open Anyway where offered, only if you trust this candidate. Do not remove quarantine or disable Gatekeeper. A local copy may not reproduce internet-download quarantine behavior. See [Apple's supported approval guidance](https://support.apple.com/en-gb/102445).
6. In the installed app click Register once. Report Enabled/Requires Approval/error and complete normal background-item approval if requested. In Activity Monitor confirm exactly one Helper; inspect its executable path (for example Open Files and Ports) to associate it with `/Applications/USB App Launcher.app/Contents/Helpers/USBAppLauncherHelper`. Record its PID. Registration status alone is not proof of execution. If registration fails, capture the exact message/state and stop without repeated retries or signing changes.

## Manual tests after successful registration

All results below are currently **NOT TESTED**. User-reported results will be recorded separately from automated observations.

| Test | Expected result |
| --- | --- |
| Auto-Launch | With MockTab initially quit and a configured CTL-472/CTL-672 disconnected, connect it: MockTab launches once. |
| Auto-Quit | Disconnect the device: the Helper-owned MockTab quits gracefully after about two seconds if Auto-Quit is enabled. |
| Reconnection | Disconnect/reconnect within two seconds: pending quit is cancelled. |
| Independence | Close the management main window: same Helper remains, and USB automation continues. |
| Live configuration | Reopen installed app, toggle a harmless preference such as Auto-Quit; verify changed behavior without Helper restart, then restore the original preference. |
| Login startup | Save work, manually log out/in: without opening management app, verify one installed Helper and working USB automation. |
| Unregister | Manually confirm Unregister: Not Registered, Helper exits, USB automation stops, JSON preserved, no management fallback. Existing user apps must not quit solely from unregistration. |
| Re-register | Register again after all earlier tests pass: exactly one Helper starts; settings remain intact. |

For unregistration preservation, compare JSON immediately before and after that action; the live-configuration test intentionally saves preferences, so do not assume an earlier whole-session hash must match. The assistant may perform read-only checks when results are reported. To leave a clean state for later work, manually Unregister in the installed app and verify process exit; do not delete configuration.

## Classification and boundaries

SMAppService registration, installed launch, Helper execution, automation, independence, login startup, unregistration and re-registration are all pending. No local compatibility PASS is claimed yet. An existing registration/process conflict is unresolved until manual status/count checks complete.

Internet-download Gatekeeper behavior, other macOS versions, other users' policies, recipient Macs, and Intel compatibility are **NOT TESTED**, not failed. Artifact is arm64-only, minimum macOS 14. A second Mac, account, or VM is not required. If all requested local tests pass, this step can be PASS for this Mac with those external limitations recorded.

Step 8C requires completion and reporting of the local tests and separate approval. No DMG creation, source/project/signing changes, service mutation, user-data changes, commit, or push occurred. Only this report was created.
