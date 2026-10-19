import SwiftUI

struct ContentView: View {
    let model: USBMonitorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("USB Device Monitor")
                .font(.title2)
            USBDeviceTable(devices: model.devices)
            USBMonitorStatus(isMonitoring: model.isMonitoring, errorMessage: model.errorMessage)
        }
        .padding()
        .frame(minWidth: 650, minHeight: 320)
    }
}

private struct USBDeviceTable: View {
    let devices: [USBDevice]

    var body: some View {
        Table(devices) {
            TableColumn("USB Device", value: \.name)
            TableColumn("Vendor ID") { device in
                Text(device.vendorIDText).monospaced()
            }
            .width(min: 85, ideal: 100)
            TableColumn("Product ID") { device in
                Text(device.productIDText).monospaced()
            }
            .width(min: 85, ideal: 100)
            TableColumn("Connection Status") { _ in
                Text("Connected")
            }
            .width(min: 135, ideal: 150)
        }
        .overlay {
            if devices.isEmpty {
                Text("No USB devices listed")
                    .foregroundStyle(.secondary)
                    .allowsHitTesting(false)
            }
        }
    }
}

private struct USBMonitorStatus: View {
    let isMonitoring: Bool
    let errorMessage: String?

    var body: some View {
        if let errorMessage {
            Text(errorMessage)
                .foregroundStyle(.red)
                .textSelection(.enabled)
        } else {
            Text(isMonitoring ? "Monitoring USB connections automatically." : "USB monitoring is stopped.")
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ContentView(model: USBMonitorViewModel())
}
