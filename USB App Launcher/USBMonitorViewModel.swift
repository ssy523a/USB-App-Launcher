import Foundation
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

    @ObservationIgnored private let monitor = USBDeviceMonitor()
    @ObservationIgnored private let store = USBRegistrationStore()
    @ObservationIgnored private var registrations: [RegisteredUSBDevice] = []
    @ObservationIgnored private var observationTask: Task<Void, Never>?
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var isStopping = false

    var canEditRegistrations: Bool { isStorageReady && !isSaving && !isStopping }

    func start() {
        guard observationTask == nil else { return }
        isStopping = false
        loadTask = Task { [weak self, store] in
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
        persist(registrations.filter { $0.id != id })
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
    }

    func stop() async {
        isStopping = true
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
