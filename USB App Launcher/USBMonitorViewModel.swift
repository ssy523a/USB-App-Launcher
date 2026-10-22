import AppKit
import Foundation
import UniformTypeIdentifiers
import Observation

@MainActor
@Observable
final class USBMonitorViewModel {
    private(set) var devices: [USBDevice] = []
    private(set) var registeredDevices: [RegisteredUSBDeviceState] = []
    private(set) var isMonitoring = false
    private(set) var errorMessage: String?
    private(set) var storageError: String?
    private(set) var isStorageReady = false
    private(set) var isSaving = false

    let automation = ApplicationAutomationService()
    private(set) var applicationMessage: String?
    private(set) var isSelectingApplication = false

    @ObservationIgnored private let monitor = USBDeviceMonitor()
    @ObservationIgnored private let store = USBRegistrationStore()
    @ObservationIgnored private var registrations: [RegisteredUSBDevice] = []
    @ObservationIgnored private var observationTask: Task<Void, Never>?
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var isStopping = false

    var canEditRegistrations: Bool { isStorageReady && !isSaving && !isStopping && !isSelectingApplication }

    func start() {
        guard observationTask == nil else { return }
        isStopping = false
        loadTask = Task { [weak self, store] in
            _ = await self?.automation.start()
            do {
                let loaded = try await store.load()
                guard let self else { return }
                registrations = loaded
                isStorageReady = true
                storageError = nil
                updateRegisteredStates()
            } catch {
                self?.storageError = "Could not load registrations: \(error.localizedDescription) The file was preserved; registration changes are disabled."
            }
        }
        let snapshots = monitor.snapshots
        observationTask = Task { [weak self] in
            for await snapshot in snapshots {
                guard !Task.isCancelled else { break }
                self?.devices = snapshot.devices
                self?.isMonitoring = snapshot.isMonitoring
                self?.errorMessage = snapshot.error
                self?.updateRegisteredStates()
            }
        }
        monitor.start()
    }

    func isRegistered(_ device: USBDevice) -> Bool {
        guard let modelID = device.modelID else { return false }
        return registrations.contains { $0.id == modelID }
    }

    func canRegister(_ device: USBDevice) -> Bool {
        canEditRegistrations && isMonitoring && device.modelID != nil
            && devices.contains(where: { $0.id == device.id }) && !isRegistered(device)
    }

    func register(_ device: USBDevice) {
        guard canRegister(device), let modelID = device.modelID else { return }
        let registration = RegisteredUSBDevice(
            deviceName: device.name, vendorID: modelID.vendorID,
            productID: modelID.productID, serialNumber: device.serialNumber
        )
        persist(registrations + [registration])
    }

    func remove(_ id: USBDevice.ModelID) {
        guard canEditRegistrations, registrations.contains(where: { $0.id == id }) else { return }
        automation.protectApplication(for: id, cancelLaunch: true)
        persist(registrations.filter { $0.id != id })
    }

    func selectApplication(for id: USBDevice.ModelID) {
        guard canEditRegistrations else { return }
        isSelectingApplication = true
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.prompt = "Select Application"
        panel.begin { [weak self] response in
            Task { @MainActor [weak self] in
                guard let self else { return }
                defer { isSelectingApplication = false }
                guard response == .OK, let url = panel.url else { return }
                do {
                    let selection = try await Task.detached(priority: .utility) {
                        try SelectedApplication.select(url)
                    }.value
                    guard !isStopping, let index = registrations.firstIndex(where: { $0.id == id }) else { return }
                    automation.protectApplication(for: id, cancelLaunch: true)
                    var updated = registrations
                    updated[index].application = selection
                    updated[index].autoQuit = false
                    applicationMessage = "Application selection takes effect on the next USB connection, or the next launch of USB App Launcher."
                    persist(updated)
                } catch {
                    applicationMessage = error.localizedDescription
                }
            }
        }
    }

    func setAutoQuit(_ enabled: Bool, for id: USBDevice.ModelID) {
        guard canEditRegistrations,
              let index = registrations.firstIndex(where: { $0.id == id }),
              registrations[index].application != nil else { return }
        var updated = registrations
        if !enabled { automation.protectApplication(for: id, cancelLaunch: false) }
        updated[index].autoQuit = enabled
        persist(updated)
    }

    private func persist(_ updated: [RegisteredUSBDevice]) {
        isSaving = true
        storageError = nil
        // Commit the UI only after successful atomic persistence. On failure the old
        // registrations remain intact, and the user can retry the same operation.
        saveTask = Task { [weak self, store] in
            do {
                try await store.save(updated)
                guard let self else { return }
                registrations = updated
                updateRegisteredStates()
            } catch {
                self?.storageError = "Could not save registrations: \(error.localizedDescription) No registration changes were applied."
            }
            self?.isSaving = false
        }
    }

    private func updateRegisteredStates() {
        registeredDevices = RegisteredUSBDeviceState.resolve(
            registrations: registrations, connections: devices
        )
        if isStorageReady && isMonitoring && !isStopping {
            automation.update(registeredDevices)
        }
    }

    func stop() async {
        isStopping = true
        await automation.stop()
        // A normal quit waits for any in-flight registration write.
        await loadTask?.value
        await saveTask?.value
        observationTask?.cancel()
        observationTask = nil
        await monitor.stop()
        devices = []
        isMonitoring = false
        updateRegisteredStates()
    }

    deinit {
        observationTask?.cancel()
        loadTask?.cancel()
    }
}
