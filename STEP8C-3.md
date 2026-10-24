# Step 8C-3 — Final DMG packaging

**PASS — DMG integrity, mounted contents and nested app signatures verified.**

- Final DMG: `/Users/seyoungseo/Downloads/USB App Launcher v1.0.dmg`
- Size: 2,368,243 bytes (2.26 MiB)
- SHA-256: `ded233f3faa89d5041a92e18fb5fa2ed7c1da19cd02bbcbdb90d71aeecd7d7bd`

## Packaging and validation

Used the verified Step 8C-2 app without rebuilding or re-signing. Staged locally under /private/tmp using ditto with metadata preservation, plus an Applications symlink targeting /Applications. Created an HFS+ compressed UDZO image using hdiutil; no Finder layout/custom-icon metadata added.

Preflight and mounted app/Helper passed strict nested codesign verification. hdiutil verify passed. Mounted read-only with nobrowse: root contained exactly USB App Launcher.app and Applications; shortcut is a symbolic link to /Applications. Main/Helper signing identifiers remain com.ssy523a.USBAppLauncher and com.ssy523a.USBAppLauncher.Helper, both ad-hoc. All mounted app file hashes and permission bits match the verified source. No FinderInfo or ResourceFork attributes appeared inside the app.

Confirmed version 1.0, arm64 for both executables, macOS 14 minimum, exactly one Helper and one BackgroundAgent plist, Label com.ssy523a.USBAppLauncher.BackgroundAgent, and no obsolete Helper plist. The unchanged-file comparison also covers entitlements/signature bytes, icon and complete LaunchAgent configuration.

Unmounted cleanly after validation. Copied the validated image to Downloads without overwriting an existing file and verified the final checksum. Temporary packaging directory was removed; existing Step 8C-2 source and preserved release folders were retained.

## Installation and limitations

Open the DMG, drag USB App Launcher.app onto Applications, eject the DMG, then launch the installed app from Applications. Existing users should unregister the old Helper and preserve their prior app before replacement; do not delete registration settings. Background service registration remains a user action in the installed app.

Apple Silicon only; macOS 14 or later. Ad-hoc signed, not notarized. The user's nine local tests passed previously; recipient Macs and internet-download Gatekeeper behavior have not been independently tested. Signature verification does not establish Gatekeeper acceptance.

macOS may block first launch. If the user trusts the source, follow the normal System Settings → Privacy & Security → Open Anyway procedure where offered after attempting launch. Do not disable Gatekeeper or remove quarantine attributes. Prior Apple guidance: https://support.apple.com/en-gb/102445.

No installed app/service, user JSON, migration backup, production source or signing setting was modified. No build, Archive, re-signing, registration, commit or push occurred. Only this report was added to the repository.
