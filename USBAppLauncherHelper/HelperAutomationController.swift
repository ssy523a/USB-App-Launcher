import Foundation

/// Startup-only, read-only configuration snapshot. No SwiftUI or second policy engine.
@MainActor
final class HelperAutomationController {
    private let automation = ApplicationAutomationService()
    private let monitor = USBDeviceMonitor()
    private let store = USBRegistrationStore()
    private var observationTask: Task<Void, Never>?
    private var stopped = false

    func start() async {
        guard !stopped, await automation.start() else { return }
        do {
            let rules = try await store.load(requireExistingFile: true)
            guard !stopped else { return }
            print("[Helper] Automation Test Mode: loaded \(rules.count) registered rules")
            observationTask = Task { [weak self, monitor] in
                for await snapshot in monitor.snapshots {
                    guard let self, !Task.isCancelled, !stopped else { break }
                    if let error = snapshot.error {
                        print("[Helper] USB monitoring failed: \(error)")
                        await stop()
                        break
                    }
                    if snapshot.isMonitoring {
                        automation.update(RegisteredUSBDeviceState.resolve(
                            registrations: rules, connections: snapshot.devices
                        ))
                    }
                }
            }
            monitor.start()
        } catch {
            print("[Helper] Automation disabled: could not load registrations: \(error.localizedDescription)")
            await automation.stop()
        }
    }

    func stop() async {
        stopped = true
        observationTask?.cancel()
        observationTask = nil
        // Cancel application work first. Shutdown never quits target apps.
        await automation.stop()
        await monitor.stop()
    }
}
