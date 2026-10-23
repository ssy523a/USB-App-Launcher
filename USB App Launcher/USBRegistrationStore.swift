import Foundation

/// Serializes management-app disk access. The Helper uses the same decoder but
/// never writes. Atomic replacement gives readers complete snapshots; it does not
/// coordinate multiple writers. Live observation is handled by ConfigurationWatcher.
actor USBRegistrationStore {
    private let fileURL: URL?
    private var lastSaved: [RegisteredUSBDevice]?
    private var didLoad = false

    nonisolated static var defaultFileURL: URL? {
        FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first?
            .appendingPathComponent("USB App Launcher", isDirectory: true)
            .appendingPathComponent("registered-devices.json")
    }

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL
    }

    nonisolated private struct Document: Codable {
        let version: Int
        let devices: [RegisteredUSBDevice]
    }

    enum StorageError: LocalizedError {
        case unavailable, invalidDocument, notLoaded

        var errorDescription: String? {
            switch self {
            case .unavailable: "The Application Support directory is unavailable."
            case .invalidDocument: "The registration file is invalid or uses an unsupported version."
            case .notLoaded: "Registrations could not be loaded. The existing file has been preserved."
            }
        }
    }

    func load(requireExistingFile: Bool = false) throws -> [RegisteredUSBDevice] {
        guard let fileURL else { throw StorageError.unavailable }
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch let error as NSError where error.domain == NSCocoaErrorDomain
            && error.code == NSFileReadNoSuchFileError {
            if requireExistingFile { throw error }
            didLoad = true
            lastSaved = []
            return []
        }
        let devices = try Self.decode(data)
        didLoad = true
        lastSaved = devices
        return devices
    }

    func save(_ devices: [RegisteredUSBDevice]) throws {
        guard didLoad else { throw StorageError.notLoaded }
        guard let fileURL else { throw StorageError.unavailable }
        try Self.validate(devices)
        guard devices != lastSaved else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(Document(version: 2, devices: devices))
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
        lastSaved = devices
    }

    /// Shared transactional decoder: no disk writes or store mutation.
    nonisolated static func decode(_ data: Data) throws -> [RegisteredUSBDevice] {
        let document = try JSONDecoder().decode(Document.self, from: data)
        guard (1...2).contains(document.version) else { throw StorageError.invalidDocument }
        try validate(document.devices)
        return document.devices
    }

    nonisolated private static func validate(_ devices: [RegisteredUSBDevice]) throws {
        guard Set(devices.map(\.id)).count == devices.count,
              devices.allSatisfy({ !$0.deviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        else { throw StorageError.invalidDocument }
    }
}
