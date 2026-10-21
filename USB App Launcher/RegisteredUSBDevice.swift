import Foundation

nonisolated struct RegisteredUSBDevice: Codable, Identifiable, Equatable, Sendable {
    let deviceName: String
    let vendorID: UInt16
    let productID: UInt16
    let serialNumber: String?
    var application: SelectedApplication?
    var autoQuit: Bool

    var id: USBDevice.ModelID {
        USBDevice.ModelID(vendorID: vendorID, productID: productID)
    }

    init(deviceName: String, vendorID: UInt16, productID: UInt16, serialNumber: String?,
         application: SelectedApplication? = nil, autoQuit: Bool = false) {
        self.deviceName = deviceName
        self.vendorID = vendorID
        self.productID = productID
        self.serialNumber = serialNumber
        self.application = application
        self.autoQuit = application != nil && autoQuit
    }

    private enum CodingKeys: String, CodingKey {
        case deviceName, vendorID, productID, serialNumber, application, autoQuit
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        deviceName = try values.decode(String.self, forKey: .deviceName)
        vendorID = try values.decode(UInt16.self, forKey: .vendorID)
        productID = try values.decode(UInt16.self, forKey: .productID)
        serialNumber = try values.decodeIfPresent(String.self, forKey: .serialNumber)
        application = try values.decodeIfPresent(SelectedApplication.self, forKey: .application)
        let preference = try values.decodeIfPresent(Bool.self, forKey: .autoQuit) ?? false
        autoQuit = application != nil && preference
    }
}

nonisolated struct RegisteredUSBDeviceState: Identifiable, Equatable, Sendable {
    let registration: RegisteredUSBDevice
    let isConnected: Bool
    var id: USBDevice.ModelID { registration.id }

    static func resolve(registrations: [RegisteredUSBDevice], connections: [USBDevice]) -> [Self] {
        let connectedModels = Set(connections.compactMap(\.modelID))
        return registrations.map {
            Self(registration: $0, isConnected: connectedModels.contains($0.id))
        }
    }
}
