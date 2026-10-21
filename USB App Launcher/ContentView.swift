import SwiftUI

struct ContentView: View {
    let model: USBMonitorViewModel
    @State private var isAddingDevice = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Registered USB Devices").font(.title2)
            RegisteredDeviceTable(model: model)
            Button("Add USB Device") { isAddingDevice = true }
                .disabled(!model.canEditRegistrations)
            RegistrationStatus(model: model)
        }
        .padding()
        .frame(minWidth: 850, minHeight: 320)
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
                Text(device.registration.deviceName)
            }
            TableColumn("Connection Status") { device in
                Text(device.isConnected ? "Connected" : "Disconnected")
            }
            .width(min: 135, ideal: 160)
            TableColumn("Auto-Launch App") { device in
                ApplicationSelectionCell(selection: device.registration.application) {
                    model.selectApplication(for: device.id)
                }
                .disabled(!model.canEditRegistrations)
            }
            .width(min: 180, ideal: 240)
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
                .help("Remove this registration")
                .disabled(!model.canEditRegistrations)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(60)
        }
        .overlay {
            if model.registeredDevices.isEmpty {
                Text(model.isStorageReady
                     ? "No registered devices. Choose Add USB Device to get started."
                     : "No registrations loaded.")
                    .foregroundStyle(.secondary)
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
