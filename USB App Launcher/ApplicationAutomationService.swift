import AppKit
import Observation

/// All decisions are serialized on the main actor. File/bookmark work runs off it.
@MainActor
@Observable
final class ApplicationAutomationService {
    private(set) var warning: String? {
        didSet {
            if let warning, warning != oldValue { print("[Automation] \(warning)") }
        }
    }
    @ObservationIgnored private var previous: [USBDevice.ModelID: RegisteredUSBDeviceState] = [:]
    @ObservationIgnored private var entries: [String: Entry] = [:]
    @ObservationIgnored private var stopped = false
    @ObservationIgnored private var lease: AutomationLease?
    @ObservationIgnored private var attemptedStart = false
    @ObservationIgnored private var terminationObserver: NSObjectProtocol?

    private final class Entry {
        let selection: SelectedApplication
        var launchTask: Task<Void, Never>?
        var quitTask: Task<Void, Never>?
        var owner: NSRunningApplication?
        var ownedLaunchDate: Date?
        var ownedURL: URL?
        var vetoQuit = false
        var quitArmed = false
        var preferenceEditPending = false
        var terminationRequested = false
        init(_ selection: SelectedApplication) { self.selection = selection }
    }

    init() {
        terminationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.discardTerminatedOwners() }
        }
    }

    /// Explicit, one-shot acquisition. A failed acquisition never auto-retries.
    func start() async -> Bool {
        guard !stopped, !attemptedStart else { return lease != nil && !stopped }
        attemptedStart = true
        do {
            let acquired = try await Task.detached(priority: .utility) {
                try AutomationLease.acquire()
            }.value
            guard !stopped else { return false }
            lease = acquired
            log("Exclusive automation ownership acquired")
            return true
        } catch {
            warning = error.localizedDescription
            return false
        }
    }

    func update(_ states: [RegisteredUSBDeviceState]) {
        guard !stopped, lease != nil else { return }
        let current = Dictionary(uniqueKeysWithValues: states.map { ($0.id, $0) })
        // Deletion, reassignment and disabling Auto-Quit must never cause a quit.
        for (id, old) in previous {
            guard let oldApp = old.registration.application else { continue }
            let new = current[id]?.registration
            if new?.application == oldApp, new?.autoQuit != old.registration.autoQuit {
                // Commit the pre-save UI protection only after the preference changed.
                entries[oldApp.key]?.preferenceEditPending = false
            }
            if new?.application != oldApp {
                if let entry = entries[oldApp.key] {
                    entry.vetoQuit = true
                    cancelQuit(entry)
                    if new?.application != oldApp {
                        entry.launchTask?.cancel()
                    }
                }
            }
        }
        var launches: [SelectedApplication] = []
        for state in states {
            guard let app = state.registration.application else { continue }
            if AutomationPolicy.shouldLaunch(previous: previous[state.id], current: state) {
                launches.append(app)
            }
            if state.isConnected, let entry = entries[app.key] {
                cancelQuit(entry)
            }
        }
        previous = current
        discardTerminatedOwners()
        for app in launches { requestLaunch(app) }
        for (key, entry) in entries {
            entry.quitArmed = AutomationPolicy.armQuit(
                previouslyArmed: entry.quitArmed, key: key, states: states
            )
            if !entry.quitArmed { cancelQuit(entry) }
            if isRequired(key) { cancelQuit(entry) }
            else { scheduleQuit(key, entry: entry) }
        }
    }

    /// Stop destructive work immediately on user edits, before disk persistence.
    /// A failed save still leaves the current running app protected.
    func protectApplication(for id: USBDevice.ModelID, cancelLaunch: Bool) {
        guard let key = previous[id]?.registration.application?.key,
              let entry = entries[key] else { return }
        if cancelLaunch { entry.vetoQuit = true }
        else { entry.preferenceEditPending = true }
        entry.quitArmed = false
        cancelQuit(entry)
        if cancelLaunch { entry.launchTask?.cancel() }
    }

    private func isRequired(_ key: String) -> Bool {
        previous.values.contains { $0.isConnected && $0.registration.application?.key == key }
    }

    private func permitsQuit(_ key: String, entry: Entry) -> Bool {
        !stopped && entry.quitArmed && !entry.preferenceEditPending
            && !entry.vetoQuit && !entry.terminationRequested
            && AutomationPolicy.permitsQuit(key: key, states: Array(previous.values))
    }

    private func requestLaunch(_ app: SelectedApplication) {
        let paths = Set(previous.values.compactMap { state -> String? in
            guard let selection = state.registration.application, selection.key == app.key else { return nil }
            return selection.path
        })
        guard paths.count == 1 else {
            warning = "Multiple selected copies of \(app.name) share an identifier. Select the same application copy for every rule."
            return
        }
        if let existing = entries[app.key] {
            cancelQuit(existing)
            guard existing.launchTask == nil else { return }
            if let owner = existing.owner, !owner.isTerminated { return }
        }
        let entry = Entry(app)
        entry.quitArmed = isRequired(app.key) && previous.values
            .filter { $0.registration.application?.key == app.key }.allSatisfy { $0.registration.autoQuit }
        entries[app.key] = entry
        entry.launchTask = Task { [weak self, weak entry] in
            guard let self, let entry else { return }
            defer {
                entry.launchTask = nil
                if !stopped { scheduleQuit(app.key, entry: entry) }
            }
            do {
                let url = try await Task.detached(priority: .utility) { try app.resolve() }.value
                guard !Task.isCancelled, !stopped, isRequired(app.key),
                      entries[app.key] === entry else { return }
                // Different copies carrying the same bundle ID are ambiguous; never
                // select a different installed copy by LaunchServices preference.
                let peers = NSWorkspace.shared.runningApplications.filter {
                    if let identifier = app.bundleIdentifier { return $0.bundleIdentifier == identifier }
                    return $0.bundleURL?.resolvingSymlinksInPath().standardizedFileURL == url
                }
                guard peers.isEmpty else {
                    log("Already running: \(app.name)")
                    return
                }
                guard url != Bundle.main.bundleURL.resolvingSymlinksInPath().standardizedFileURL else {
                    warning = "USB App Launcher cannot automate itself."
                    return
                }
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = false
                configuration.addsToRecentItems = false
                configuration.createsNewApplicationInstance = false
                configuration.allowsRunningApplicationSubstitution = false
                configuration.promptsUserIfNeeded = false
                let requestedAt = Date()
                log("Launch requested: \(app.name)")
                let running = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
                guard !stopped, !Task.isCancelled, entries[app.key] === entry else { return }
                // Keep the actual returned instance, not a later lookup by PID/name.
                // Missing or earlier launch dates make ownership unprovable.
                guard !running.isTerminated, let date = running.launchDate, date >= requestedAt,
                      running.bundleIdentifier == app.bundleIdentifier,
                      running.bundleURL?.resolvingSymlinksInPath().standardizedFileURL == url
                else {
                    warning = "Launched or found \(app.name), but ownership could not be verified. Auto-Quit will not apply."
                    return
                }
                entry.owner = running
                entry.ownedLaunchDate = date
                entry.ownedURL = url
            } catch {
                if !stopped && !Task.isCancelled {
                    warning = "\(app.name): \(error.localizedDescription)"
                }
            }
        }
    }

    private func scheduleQuit(_ key: String, entry: Entry) {
        guard entry.launchTask == nil, entry.quitTask == nil,
              entry.owner != nil, permitsQuit(key, entry: entry) else { return }
        log("Auto-quit scheduled: \(entry.selection.name)")
        entry.quitTask = Task { [weak self, weak entry] in
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            guard let self, let entry else { return }
            entry.quitTask = nil
            guard entries[key] === entry, permitsQuit(key, entry: entry),
                  let owner = entry.owner, !owner.isTerminated,
                  owner.launchDate == entry.ownedLaunchDate,
                  owner.bundleIdentifier == entry.selection.bundleIdentifier,
                  owner.bundleURL?.resolvingSymlinksInPath().standardizedFileURL == entry.ownedURL,
                  owner.processIdentifier != NSRunningApplication.current.processIdentifier
            else { return }
            // At most one normal termination request for this owned instance.
            entry.terminationRequested = true
            if owner.terminate() {
                log("Graceful termination requested: \(entry.selection.name)")
            } else {
                warning = "\(entry.selection.name) declined the termination request. It will remain running."
            }
        }
    }

    private func cancelQuit(_ entry: Entry) {
        if let task = entry.quitTask {
            task.cancel()
            entry.quitTask = nil
            log("Auto-quit cancelled: \(entry.selection.name)")
        }
    }

    private func discardTerminatedOwners() {
        for entry in entries.values where entry.owner?.isTerminated == true {
            cancelQuit(entry)
            entry.owner = nil
            entry.ownedLaunchDate = nil
            entry.ownedURL = nil
        }
        // Termination notifications never trigger a launch.
    }

    func stop() async {
        stopped = true
        let pendingLaunches = entries.values.compactMap(\.launchTask)
        for entry in entries.values {
            cancelQuit(entry)
            entry.launchTask?.cancel()
            entry.owner = nil
        }
        // Keep ownership until submitted launch requests have settled. Cancellation
        // cannot retract a request already sent to LaunchServices.
        for task in pendingLaunches { await task.value }
        entries.removeAll()
        lease = nil
        if let terminationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(terminationObserver)
            self.terminationObserver = nil
        }
    }

    deinit {
        if let terminationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(terminationObserver)
        }
    }

    private func log(_ message: String) {
        #if DEBUG
        print("[Automation] \(message)")
        #endif
    }
}

/// Pure transition policy, also used by executable verification.
nonisolated enum AutomationPolicy {
    static func shouldLaunch(previous: RegisteredUSBDeviceState?, current: RegisteredUSBDeviceState) -> Bool {
        guard current.isConnected, current.registration.application != nil else { return false }
        guard let previous else { return true } // Startup enumeration.
        // A saved application change safely initializes demand for the new target.
        return !previous.isConnected || previous.registration.application != current.registration.application
    }

    /// Consent may arm only while there is connected demand. Enabling on a
    /// disconnected model cannot retroactively quit an already-running instance.
    static func armQuit(previouslyArmed: Bool, key: String, states: [RegisteredUSBDeviceState]) -> Bool {
        let rules = states.filter { $0.registration.application?.key == key }
        guard !rules.isEmpty, rules.allSatisfy({ $0.registration.autoQuit }) else { return false }
        return previouslyArmed || rules.contains { $0.isConnected }
    }

    static func permitsQuit(key: String, states: [RegisteredUSBDeviceState]) -> Bool {
        let rules = states.filter { $0.registration.application?.key == key }
        return !rules.isEmpty
            && Set(rules.compactMap { $0.registration.application?.path }).count == 1
            && rules.allSatisfy { !$0.isConnected && $0.registration.autoQuit }
    }
}
