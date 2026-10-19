import Foundation

/// A registry ID identifies one connection, not a device across unplug/replug or reboot.
nonisolated struct USBDevice: Identifiable, Equatable, Sendable {
    let registryEntryID: UInt64
    let name: String
    let vendorID: UInt16?
    let productID: UInt16?
    let serialNumber: String?

    var id: UInt64 { registryEntryID }

    /// Model identity is shared by all units of the same model.
    var modelID: ModelID? {
        guard let vendorID, let productID else { return nil }
        return ModelID(vendorID: vendorID, productID: productID)
    }

    var vendorIDText: String { vendorID.map { String(format: "%04X", Int($0)) } ?? "—" }
    var productIDText: String { productID.map { String(format: "%04X", Int($0)) } ?? "—" }

    nonisolated struct ModelID: Hashable, Sendable {
        let vendorID: UInt16
        let productID: UInt16
    }
}
