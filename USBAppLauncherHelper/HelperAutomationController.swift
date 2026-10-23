import Foundation

/// Serializes USB snapshots and complete, validated configuration changes on the main actor.
@MainActor
final class HelperAutomationController {
    private let automation = ApplicationAutomationService()
    private let monitor = USBDeviceMonitor()
    private var watcher: ConfigurationWatcher?
    private var configurationTask: Task<Void, Never>?
    private var observationTask: Task<Void, Never>?
    private var rules: [RegisteredUSBDevice]?
    private var devices: [USBDevice] = []
    private var monitoring = false
    private var stopped = false
    private var shutdownTask: Task<Void, Never>?

    func start() async {
        guard !stopped, await automation.start() else { return }
        guard !stopped, let url = USBRegistrationStore.defaultFileURL else {
            await stop()
            return
        }
        let watcher = ConfigurationWatcher(url: url)
        self.watcher = watcher
        configurationTask = Task { [weak self] in
            for await event in watcher.events {
                guard let self, !stopped, !Task.isCancelled else { break }
                switch event {
                case .rules(let updated):
                    let old = Dictionary(uniqueKeysWithValues: (rules ?? []).map { ($0.id, $0) })
                    let new = Dictionary(uniqueKeysWithValues: updated.map { ($0.id, $0) })
                    log("Configuration reloaded")
                    log("Rules updated: added=\(new.keys.filter { old[$0] == nil }.count), removed=\(old.keys.filter { new[$0] == nil }.count), modified=\(new.keys.filter { old[$0] != nil && old[$0] != new[$0] }.count)")
                    if rules != updated {
                        rules = updated
                        reconcile()
                    }
                    if observationTask == nil { startMonitoring() }
                case .invalid:
                    print("[Helper] Configuration invalid or unavailable; retaining previous rules")
                case .unavailable:
                    print("[Helper] Configuration directory monitoring unavailable; automation stopped")
                    await stop()
                    return
                }
            }
        }
        // Arm observation before the initial read: no load/watch gap.
        watcher.start()
    }

    private func startMonitoring() {
        observationTask = Task { [weak self, monitor] in
            for await snapshot in monitor.snapshots {
                guard let self, !Task.isCancelled, !stopped else { break }
                if snapshot.error != nil {
                    print("[Helper] USB monitoring failed; automation stopped")
                    await stop()
                    break
                }
                devices = snapshot.devices
                monitoring = snapshot.isMonitoring
                reconcile()
            }
        }
        monitor.start()
    }

    private func reconcile() {
        guard !stopped, monitoring, let rules else { return }
        automation.update(RegisteredUSBDeviceState.resolve(
            registrations: rules, connections: devices
        ))
    }

    func stop() async {
        if let shutdownTask {
            await shutdownTask.value
            return
        }
        stopped = true
        configurationTask?.cancel()
        observationTask?.cancel()
        configurationTask = nil
        observationTask = nil
        // Concurrent error/signal shutdown paths join the same cleanup operation.
        let task = Task { [automation, watcher, monitor] in
            await automation.stop()
            await watcher?.stop()
            await monitor.stop()
        }
        shutdownTask = task
        await task.value
        watcher = nil
    }

    private func log(_ message: String) {
        #if DEBUG
        print("[Helper] \(message)")
        #endif
    }
}
