import SwiftUI

struct ContentView: View {
    let model: USBMonitorViewModel
    @State private var isAddingDevice = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Registered USB Devices").font(.title2)
            RegisteredDeviceTable(model: model)
            Button("Add USB Device", systemImage: "plus") { isAddingDevice = true }
                .disabled(!model.canEditRegistrations)
            RegistrationStatus(model: model)
            Divider()
            BackgroundHelperSection()
        }
        .padding(20)
        .frame(minWidth: 850, minHeight: 520)
        .sheet(isPresented: $isAddingDevice) {
            AddUSBDeviceView(model: model)
        }
    }
}

private struct RegisteredDeviceTable: View {
    let model: USBMonitorViewModel

    var body: some View {
        Table(model.registeredDevices) {
            TableColumn("USB Device") { device in
                VStack(alignment: .leading, spacing: 3) {
                    Text(device.registration.deviceName)
                        .lineLimit(1)
                        .help(device.registration.deviceName)
                    Text(String(format: "%04X:%04X",
                                Int(device.registration.vendorID), Int(device.registration.productID)))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 5)
            }
            .width(min: 170, ideal: 230)
            TableColumn("Connection Status") { device in
                Label {
                    Text(device.isConnected ? "Connected" : "Disconnected")
                } icon: {
                    Image(systemName: device.isConnected ? "checkmark.circle.fill" : "minus.circle")
                        .foregroundStyle(device.isConnected ? Color.green : Color.secondary)
                }
            }
            .width(min: 140, ideal: 150, max: 180)
            TableColumn("Auto-Launch App") { device in
                ApplicationSelectionCell(selection: device.registration.application) {
                    model.selectApplication(for: device.id)
                }
                .disabled(!model.canEditRegistrations)
            }
            .width(min: 210, ideal: 250)
            TableColumn("Auto-Quit") { device in
                Toggle("Auto-Quit", isOn: Binding(
                    get: { device.registration.autoQuit },
                    set: { model.setAutoQuit($0, for: device.id) }
                ))
                .toggleStyle(.checkbox)
                .labelsHidden()
                .accessibilityLabel("Auto-Quit for \(device.registration.deviceName)")
                .disabled(device.registration.application == nil || !model.canEditRegistrations)
            }
            .width(75)
            TableColumn("Delete") { device in
                Button {
                    model.remove(device.id)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Remove \(device.registration.deviceName)")
                .help("Remove Device")
                .disabled(!model.canEditRegistrations)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(60)
        }
        .alternatingRowBackgrounds(.disabled)
        .frame(minHeight: 160)
        .overlay {
            if model.registeredDevices.isEmpty {
                VStack(spacing: 6) {
                    Text(model.isStorageReady ? "No Registered USB Devices" : "No Registrations Loaded")
                        .font(.headline)
                    Text("Connect a USB device, then choose Add USB Device below.")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .allowsHitTesting(false)
            }
        }
    }
}

private struct RegistrationStatus: View {
    let model: USBMonitorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let error = model.storageError {
                Text(error).foregroundStyle(.red).textSelection(.enabled)
            }
            if let error = model.errorMessage {
                Text(error).foregroundStyle(.red).textSelection(.enabled)
            }
            if let warning = model.automation.warning {
                Text(warning).foregroundStyle(.secondary).textSelection(.enabled)
            }
            if let message = model.applicationMessage {
                Text(message).foregroundStyle(.secondary)
            }
            if model.isSaving {
                Text("Saving registration…").foregroundStyle(.secondary)
            } else if !model.isStorageReady && model.storageError == nil {
                Text("Loading registrations…").foregroundStyle(.secondary)
            } else if model.isMonitoring {
                Text("Connection status updates automatically.").foregroundStyle(.secondary)
            } else {
                Text("USB monitoring is stopped.").foregroundStyle(.secondary)
            }
        }
        .font(.callout)
    }
}

private struct BackgroundHelperSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Background Helper")
                .font(.headline)
            Text("Automatically monitors USB devices and runs configured applications after login.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Label("Not Available", systemImage: "minus.circle")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Register") {}
                    .disabled(true)
                Button("Unregister") {}
                    .disabled(true)
            }
            Text("Available in a future version")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }
}
