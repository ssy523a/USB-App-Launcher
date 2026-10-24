# USB App Launcher

A free macOS utility that launches selected applications when registered USB devices connect and can gracefully quit them when those devices disconnect. A native SwiftUI management app configures a separate Background Helper that performs automation.

## Download and requirements

[Download USB App Launcher v1.0](https://github.com/ssy523a/USB-App-Launcher/releases/tag/v1.0) — currently marked as a GitHub pre-release.

- macOS 14 or later
- Apple Silicon Mac (arm64); the distributed app does not support Intel Macs

## Features

- Event-driven USB detection without polling.
- Persistent device registrations matched by exact Vendor ID and Product ID.
- Per-device application selection and optional Auto-Quit.
- A cancellable two-second disconnection grace period.
- Protection for applications already running before automation; graceful termination only.
- Shared application-demand protection when several registered devices use one application.
- Live configuration updates and a background service that can start at login.

Devices with the same Vendor ID and Product ID are treated as one model. That model stays connected while at least one matching physical device remains connected.

## Install

1. Download `USB App Launcher v1.0.dmg` from the release page.
2. Open the DMG and drag **USB App Launcher.app** onto **Applications**.
3. Eject the DMG, then open the app from Applications.
4. Follow the Background Helper setup below to enable automation.

When replacing an existing version, unregister its Helper first and preserve the old app as a backup. Keep your registration settings. Run the installed copy rather than the copy inside the DMG.

## Background Helper

In the management app's **Background Helper** section, click **Register**. If approval is required, follow the app's guidance to macOS Login Items settings and allow background execution.

**Enabled** describes registration status; it is not proof that the Helper is running. If automation does not start, check approval and look for `USBAppLauncherHelper` in Activity Monitor. Report any registration error rather than repeatedly registering.

Closing the main management window quits that app. The independently running Helper continues automation, including after login when registered and approved. The management app itself performs no application automation.

To stop background automation, reopen the installed app, click **Unregister**, and confirm. This preserves device settings and does not intentionally quit configured applications merely because the service stops. Unregistration controls the managed service; independently started development Helpers are separate.

## Configure USB devices

1. Connect a USB device and click **Add USB Device**.
2. Select it from the connected-device list. Already registered models cannot be added twice.
3. Use **Choose App...** in its row to select a macOS application.
4. Enable **Auto-Quit** if you want graceful termination after disconnection, subject to ownership and shared-device protections. Leave it unchecked to keep the application open.

Registered devices remain listed while disconnected. Changes are saved automatically and applied by the running Helper. The trash button removes only that registration, not the physical device. Removing a registration does not itself quit its previously selected application.

Auto-Quit applies only to an instance reliably identified as launched by automation and no longer required by another connected registered device. Rapid reconnection cancels the pending quit. Unsaved-document prompts and an application's refusal to quit are respected. A manually quit application is not repeatedly relaunched while its device remains connected.

## Security and compatibility

The distributed app is **ad-hoc signed and not Apple-notarized**. Gatekeeper may block first launch or require approval. If you trust the source, follow normal macOS **System Settings → Privacy & Security → Open Anyway** procedures where available after attempting to open it. Do not disable Gatekeeper or remove quarantine attributes. System policy may still prevent launch.

Functional and login tests passed on the developer's Mac. The DMG and a temporary installation copy passed integrity and signature checks. Internet-download Gatekeeper behavior and compatibility on recipient Macs have not been independently verified. No universal compatibility is claimed.

## Developer

Seo, Se-young  
Contact: [ssy523a@gmail.com](mailto:ssy523a@gmail.com)
