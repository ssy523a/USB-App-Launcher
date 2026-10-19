import Foundation

/// Persistent model-level registration. Names and serial numbers are metadata only.
nonisolated struct RegisteredUSBDevice: Codable, Identifiable, Equatable, Sendable {
    let deviceName: String
    let vendorID: UInt16
    let productID: UInt16
    let serialNumber: String?

    // Deterministic across launches; no registry ID or connection status is encoded.
    var id: USBDevice.ModelID {
        USBDevice.ModelID(vendorID: vendorID, productID: productID)
    }
}

/// Runtime projection kept separate from the Codable registration.
nonisolated struct RegisteredUSBDeviceState: Identifiable, Equatable, Sendable {
    let registration: RegisteredUSBDevice
    let isConnected: Bool
    var id: USBDevice.ModelID { registration.id }

    static func resolve(
        registrations: [RegisteredUSBDevice], connections: [USBDevice]
    ) -> [Self] {
        let connectedModels = Set(connections.compactMap(\.modelID))
        return registrations.map {
            Self(registration: $0, isConnected: connectedModels.contains($0.id))
        }
    }
}
