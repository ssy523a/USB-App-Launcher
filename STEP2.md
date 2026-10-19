# Step 2: USB registrations

The IOKit monitor is unchanged. `USBMonitorViewModel` combines live connection
snapshots with persistent registrations on the main actor. No polling is used.

## Files and identity

- `RegisteredUSBDevice.swift`: Codable registration metadata and a separate,
  non-Codable runtime connection-state projection.
- `USBRegistrationStore.swift`: actor-isolated JSON loading, validation, and
  atomic replacement off the main actor.
- `AddUSBDeviceView.swift`: live connected-device picker with duplicate and
  missing-ID protection.
- `ContentView.swift`: registered-device table, status, and removal controls.

The exact numeric vendor/product pair is the stable registration ID. Names are
display-only. Serial numbers are saved as optional metadata but never affect
matching. Registry IDs remain limited to active connections. A model is connected
while at least one physical connection matches its pair. Missing vendor/product
IDs prevent registration. Composite interfaces remain handled by the existing
device-level monitor; hardware exposing several device models can have several
registrations. Separate physical units of one model intentionally share a row.

## Storage and failures

The file is `USB App Launcher/registered-devices.json` beneath the user-domain
Application Support directory returned by FileManager. With App Sandbox enabled,
this resolves inside the application's sandbox container. The version-1 JSON
envelope stores only names, vendor/product IDs, and optional serial numbers.
Neither connection status nor registry IDs are persisted.

The directory is created on the first changed registration save. A missing file
means an empty registration list. Invalid JSON, unsupported versions, duplicate
model pairs, invalid numeric IDs, and unreadable files surface an error and
disable editing for that launch without overwriting the file. To recover, quit,
back up and repair or move the file, then relaunch. Save failures retain the old
UI registrations and permit retry. Unchanged registrations and USB events do not
write to disk. Normal quit waits for pending writes; forced termination can lose
an unfinished operation, but atomic replacement protects the previous file.

This store currently supports one writer. A future Helper will need an explicitly
shared storage location (for example an App Group) and a single owner with IPC or
coordinated cross-process transactions. Atomic replacement alone cannot prevent
lost updates from independent writers. No Helper, App Group, or IPC is added here.

## Verification

Xcode build succeeded. Temporary-file executable checks verified missing-file
handling, save/load round-trip, deletion, duplicate rejection, omission of runtime
state from JSON, malformed-file preservation, and multiple-connection matching.

Manual hardware and UI checks:

1. Run with Command + R and CTL-472 connected. Choose Add USB Device, select
   CTL-472 (056A:037A), and Add. Confirm one Connected row.
2. Open Add USB Device again. Confirm CTL-472 is already registered and cannot
   be added again.
3. Disconnect CTL-472. Its row must remain and show Disconnected. Reconnect it;
   the same row must show Connected. Repeat several times.
4. Connect and register H3 (04E8:6183). Confirm it gets a separate row.
5. Quit normally and relaunch with either device disconnected. Both registrations
   must remain, with status reflecting the current connections after enumeration.
6. Delete H3 using its trash button. Confirm CTL-472 remains, H3 hardware stays
   connected, and H3 is available to register again. Relaunch to verify deletion.
7. With two physical units of one model, remove one: the registered row must
   stay Connected until the final unit is disconnected.
8. Check the empty registered list and disconnected-device picker, and Light/Dark
   appearance. Physical reconnects and these UI checks require manual validation.

No Step 3 functionality is implemented. No commit or push is performed.
