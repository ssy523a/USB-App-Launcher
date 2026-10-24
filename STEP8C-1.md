# Step 8C-1 — Safe repository cleanup

**Cleanup complete; packaging blocked by preserved release signature validation.** User reports all nine Step 8B-6 manual tests passed. No functional tests were repeated.

## Removed

- `LaunchAgents/com.ssy523a.USBAppLauncher.Helper.plist`: obsolete, absent from current project/build/source references. Current BackgroundAgent plist remains.
- Root `registered-devices.json`: unused empty version-1 migration copy; byte-identical to the retained migration backup (SHA-256 c3dd0920ca8e598947e979767d99755dbb02002505f0db452ecf11be82854a1b). Runtime storage explicitly uses Application Support; Step5C tests generate temporary JSON rather than reading this root file.
- Four generated metadata files: root `.DS_Store`, `Verification/.DS_Store`, `USB App Launcher/.DS_Store`, and `USB App Launcher/Assets.xcassets/.DS_Store`.

## Retained and exclusions

- Migration Backups retained intact. Archiving elsewhere could be reasonable after verifying the archive, but no automatic removal is appropriate for migration history.
- All Swift sources, assets, current plist, shared schemes, verification tests and STEP reports retained.
- All xcuserdata and xcuserstate files retained locally. Only the tracked per-user `xcschememanagement.plist` was removed from Git's index; that deletion is staged, not committed. Shared target schemes remain tracked.
- `.gitignore` preserves the existing `/USB-App-Launcher-Release/` exclusion and adds `.DS_Store`, `._*`, `__MACOSX/`, `**/xcuserdata/`, and `*.xcuserstate`. No additional AppleDouble or __MACOSX items were found outside the protected release folder.
- The entire release directory, including its own metadata and signing-support plists, was excluded from cleanup. No uncertain extra files were removed.

## Verification and issue

Initial Git working tree was clean. Targeted project/source reference checks found only BackgroundAgent configured for embedding; neither deleted file was a required project input. Production code and project configuration were not changed. Step 8B-6's successful Release build is reused; no rebuild was necessary for removal of unreferenced files. All production identifiers, signing settings and Copy Files phases remain unchanged.

The preserved app contains exactly one Helper and one BackgroundAgent plist with the expected Label; no obsolete Helper LaunchAgent plist is embedded.

**Current strict verification of the preserved app failed:** `resource fork, Finder information, or similar detritus not allowed`. Earlier signature success does not override this current result. No metadata was stripped, no quarantine changed, and no re-signing or replacement was performed. The release folder was read only. This issue needs separate approval/investigation before packaging, preferably using a separate copy while preserving this candidate. No claim is made that cleanup caused the pre-existing release metadata condition.

## Git summary and boundaries

- Modified: `.gitignore`.
- Deleted from working tree: obsolete LaunchAgents plist and root JSON.
- Index-only deletion: per-user scheme-management plist; local file retained.
- Added: `STEP8C-1.md`.
- Untracked generated .DS_Store files removed as listed above.

Installed /Applications app, live Helper/service state, Application Support registration data, migration backups, and preserved release candidate were not modified. No install, registration, process action, DMG, commit or push. Cleanup ends here; next action is to resolve the release-signature metadata blocker under a separate approved task.
