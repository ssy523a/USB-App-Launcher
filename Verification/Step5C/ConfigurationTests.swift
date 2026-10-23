import Foundation
import Testing
@testable import Core

private enum Failure: Error { case timeout, ended }

private func next(_ stream: AsyncStream<ConfigurationWatcher.Event>) async throws -> ConfigurationWatcher.Event {
    try await withThrowingTaskGroup(of: ConfigurationWatcher.Event.self) { group in
        group.addTask {
            for await event in stream { return event }
            throw Failure.ended
        }
        group.addTask {
            try await Task.sleep(for: .seconds(5))
            throw Failure.timeout
        }
        defer { group.cancelAll() }
        guard let event = try await group.next() else { throw Failure.ended }
        return event
    }
}

private struct Document: Encodable {
    var version = 2
    var devices: [RegisteredUSBDevice]
}

private func bytes(_ devices: [RegisteredUSBDevice]) throws -> Data {
    try JSONEncoder().encode(Document(devices: devices))
}

private func rule(_ name: String = "Fixture", autoQuit: Bool = false) -> RegisteredUSBDevice {
    RegisteredUSBDevice(deviceName: name, vendorID: 1386, productID: 890,
                        serialNumber: nil, application: app, autoQuit: autoQuit)
}

private let app = SelectedApplication(bundleIdentifier: "test.fixture", path: "/Fixture.app",
                                      name: "Fixture", bookmark: nil)

@Suite(.serialized)
struct ConfigurationTests {
    @Test func replacementDeletionCorruptionAndRecovery() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("registered-devices.json")
        try bytes([rule()]).write(to: url, options: .atomic)
        let watcher = ConfigurationWatcher(url: url)
        watcher.start()
        do {
            if case .rules(let rules) = try await next(watcher.events) { #expect(rules == [rule()]) }
            else { Issue.record("Initial rules missing") }

            try bytes([rule("Updated", autoQuit: true)]).write(to: url, options: .atomic)
            if case .rules(let rules) = try await next(watcher.events) {
                #expect(rules == [rule("Updated", autoQuit: true)])
            } else { Issue.record("Atomic replacement missed") }

            let damaged = Data("{partial".utf8)
            try damaged.write(to: url, options: .atomic)
            if case .invalid = try await next(watcher.events) {} else { Issue.record("Invalid accepted") }
            #expect(try Data(contentsOf: url) == damaged)

            // Recovery to the same last-valid rules must still be reported.
            try bytes([rule("Updated", autoQuit: true)]).write(to: url, options: .atomic)
            if case .rules(let rules) = try await next(watcher.events) { #expect(rules.count == 1) }
            else { Issue.record("Recovery missed") }

            let moved = directory.appendingPathComponent("renamed.json")
            try FileManager.default.moveItem(at: url, to: moved)
            if case .invalid = try await next(watcher.events) {} else { Issue.record("Missing file accepted") }
            #expect(!FileManager.default.fileExists(atPath: url.path))
            try bytes([]).write(to: url, options: .atomic)
            if case .rules(let rules) = try await next(watcher.events) { #expect(rules.isEmpty) }
            else { Issue.record("Valid empty recreation missed") }

            // Non-atomic edits are detected by the file source; partial data is rejected.
            try bytes([rule("In-place")]).write(to: url)
            if case .rules(let rules) = try await next(watcher.events) { #expect(rules == [rule("In-place")]) }
            else { Issue.record("In-place write missed") }
        } catch {
            await watcher.stop()
            throw error
        }
        await watcher.stop()
    }

    @Test func rapidWritesStayOrderedAndReachLatest() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("registered-devices.json")
        let watcher = ConfigurationWatcher(url: url)
        watcher.start()
        do {
            if case .invalid = try await next(watcher.events) {} else { Issue.record("Missing startup accepted") }
            for i in 0...30 { try bytes([rule(String(i))]).write(to: url, options: .atomic) }
            var last = -1
            while last < 30 {
                if case .rules(let rules) = try await next(watcher.events) {
                    let current = try #require(Int(rules[0].deviceName))
                    #expect(current > last)
                    last = current
                } else { Issue.record("Valid atomic writes produced invalid state") }
            }
            // A no-op save must not enqueue a redundant rules update.
            try bytes([rule("30")]).write(to: url, options: .atomic)
            try await Task.sleep(for: .milliseconds(100)) // Test observation window only.
            await watcher.stop()
            var iterator = watcher.events.makeAsyncIterator()
            #expect(await iterator.next() == nil)
        } catch { await watcher.stop(); throw error }
    }

    @Test func validationAndTransitionPolicies() throws {
        #expect(throws: (any Error).self) { try USBRegistrationStore.decode(bytes([rule(), rule()])) }
        #expect(throws: (any Error).self) {
            try USBRegistrationStore.decode(Data(#"{"version":99,"devices":[]}"#.utf8))
        }
        let legacy = Data(#"{"version":1,"devices":[{"deviceName":"Old","vendorID":1,"productID":2}]}"#.utf8)
        let old = try USBRegistrationStore.decode(legacy)
        #expect(old.count == 1 && old[0].application == nil && !old[0].autoQuit)
        let connected = RegisteredUSBDeviceState(registration: rule(autoQuit: true), isConnected: true)
        let disconnected = RegisteredUSBDeviceState(registration: rule(autoQuit: true), isConnected: false)
        #expect(AutomationPolicy.shouldLaunch(previous: nil, current: connected))
        #expect(!AutomationPolicy.shouldLaunch(previous: connected, current: connected))
        var changed = rule(autoQuit: true)
        changed.application = SelectedApplication(bundleIdentifier: "test.second", path: "/Second.app", name: "Second", bookmark: nil)
        #expect(AutomationPolicy.shouldLaunch(previous: connected, current: .init(registration: changed, isConnected: true)))
        #expect(!AutomationPolicy.armQuit(previouslyArmed: false, key: app.key, states: [disconnected]))
        #expect(AutomationPolicy.armQuit(previouslyArmed: false, key: app.key, states: [connected]))
        #expect(AutomationPolicy.armQuit(previouslyArmed: true, key: app.key, states: [disconnected]))
        let disabled = RegisteredUSBDeviceState(registration: rule(), isConnected: false)
        #expect(!AutomationPolicy.armQuit(previouslyArmed: true, key: app.key, states: [disabled]))
        #expect(!AutomationPolicy.permitsQuit(key: app.key, states: [connected, disconnected]))
        #expect(!AutomationPolicy.permitsQuit(key: app.key, states: [disabled, disconnected]))
        #expect(!AutomationPolicy.permitsQuit(key: app.key, states: []))
    }
}
