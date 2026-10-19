import Foundation
import Observation

@MainActor
@Observable
final class USBMonitorViewModel {
    private(set) var devices: [USBDevice] = []
    private(set) var isMonitoring = false
    private(set) var errorMessage: String?

    @ObservationIgnored private let monitor = USBDeviceMonitor()
    @ObservationIgnored private var observationTask: Task<Void, Never>?

    func start() {
        guard observationTask == nil else { return }
        let snapshots = monitor.snapshots
        observationTask = Task { [weak self] in
            for await snapshot in snapshots {
                guard !Task.isCancelled else { break }
                self?.devices = snapshot.devices
                self?.isMonitoring = snapshot.isMonitoring
                self?.errorMessage = snapshot.error
            }
        }
        monitor.start()
    }

    func stop() async {
        observationTask?.cancel()
        observationTask = nil
        await monitor.stop()
        devices = []
        isMonitoring = false
    }

    deinit {
        observationTask?.cancel()
    }
}
