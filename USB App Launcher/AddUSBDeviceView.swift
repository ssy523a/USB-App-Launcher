import SwiftUI

struct AddUSBDeviceView: View {
    let model: USBMonitorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedID: USBDevice.ID?

    private var selectedDevice: USBDevice? {
        model.devices.first { $0.id == selectedID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add USB Device").font(.title2)
            Text("Select a connected device. Registration applies to all devices with the same Vendor ID and Product ID.")
                .foregroundStyle(.secondary)
            Table(model.devices, selection: $selectedID) {
                TableColumn("USB Device", value: \.name)
                TableColumn("Vendor ID") { device in
                    Text(device.vendorIDText).monospaced()
                }
                .width(85)
                TableColumn("Product ID") { device in
                    Text(device.productIDText).monospaced()
                }
                .width(85)
                TableColumn("Registration") { device in
                    if model.isRegistered(device) {
                        Text("Already registered")
                    } else if device.modelID == nil {
                        Text("IDs unavailable")
                    } else {
                        Text("Available")
                    }
                }
                .width(140)
            }
            .overlay {
                if model.devices.isEmpty {
                    Text("No connected USB devices. Connect a device to add it.")
                        .foregroundStyle(.secondary)
                        .allowsHitTesting(false)
                }
            }
            RegistrationSheetError(message: model.storageError ?? model.errorMessage)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add") {
                    if let selectedDevice { model.register(selectedDevice) }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedDevice.map { !model.canRegister($0) } ?? true)
            }
        }
        .padding()
        .frame(width: 720, height: 380)
        .onChange(of: model.isSaving) { wasSaving, isSaving in
            if wasSaving && !isSaving && model.storageError == nil {
                dismiss()
            }
        }
    }
}

private struct RegistrationSheetError: View {
    let message: String?

    var body: some View {
        if let message {
            Text(message).foregroundStyle(.red).textSelection(.enabled)
        }
    }
}
