import Foundation

/// Serializes disk access off the main actor. One writer per process for Step 2.
/// A future helper needs a shared container and coordinated writes (or one owning
/// process with IPC). Atomic replacement alone does not prevent lost updates
/// between independent processes. No App Group or IPC is configured here.
actor USBRegistrationStore {
    private let fileURL: URL?
    private var lastSaved: [RegisteredUSBDevice]?
    private var didLoad = false

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first?
            .appendingPathComponent("USB App Launcher", isDirectory: true)
            .appendingPathComponent("registered-devices.json")
    }

    private struct Document: Codable {
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

    func load() throws -> [RegisteredUSBDevice] {
        guard let fileURL else { throw StorageError.unavailable }
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch let error as NSError where error.domain == NSCocoaErrorDomain
            && error.code == NSFileReadNoSuchFileError {
            didLoad = true
            lastSaved = []
            return []
        }
        let document = try JSONDecoder().decode(Document.self, from: data)
        guard (1...2).contains(document.version) else { throw StorageError.invalidDocument }
        try validate(document.devices)
        didLoad = true
        lastSaved = document.devices
        return document.devices
    }

    func save(_ devices: [RegisteredUSBDevice]) throws {
        guard didLoad else { throw StorageError.notLoaded }
        guard let fileURL else { throw StorageError.unavailable }
        try validate(devices)
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

    private func validate(_ devices: [RegisteredUSBDevice]) throws {
        guard Set(devices.map(\.id)).count == devices.count,
              devices.allSatisfy({ !$0.deviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        else { throw StorageError.invalidDocument }
    }
}
