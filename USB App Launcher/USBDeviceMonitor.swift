import Foundation
import IOKit
import IOKit.usb

/// UI-independent, read-only observer. A monitor has one snapshot consumer.
nonisolated final class USBDeviceMonitor: Sendable {
    nonisolated struct Snapshot: Sendable {
        let devices: [USBDevice]
        let isMonitoring: Bool
        let error: String?
    }

    let snapshots: AsyncStream<Snapshot>
    private let worker: Worker

    init() {
        let (stream, continuation) = AsyncStream<Snapshot>.makeStream(bufferingPolicy: .bufferingNewest(1))
        snapshots = stream
        worker = Worker(continuation: continuation)
    }

    func start() {
        let worker = worker
        worker.queue.async { worker.start() }
    }

    /// Returns only after callbacks and resource cleanup on the serial queue complete.
    func stop() async {
        let worker = worker
        await withCheckedContinuation { continuation in
            worker.queue.async {
                worker.stop()
                continuation.resume()
            }
        }
    }

    deinit {
        // Keep the callback context alive until its notification port is destroyed.
        let worker = worker
        worker.queue.async {
            worker.stop()
            worker.continuation.finish()
        }
    }

    /// All mutable state and C callbacks are confined to queue.
    /// @unchecked Sendable expresses that queue confinement, not arbitrary thread safety.
    private nonisolated final class Worker: @unchecked Sendable {
        let queue = DispatchQueue(label: "USBAppLauncher.USBDeviceMonitor", qos: .utility)
        let continuation: AsyncStream<Snapshot>.Continuation
        private var port: IONotificationPortRef?
        private var addedIterator: io_iterator_t = 0
        private var removedIterator: io_iterator_t = 0
        private var devices: [UInt64: USBDevice] = [:]
        private var isMonitoring = false

        init(continuation: AsyncStream<Snapshot>.Continuation) {
            self.continuation = continuation
        }

        func start() {
            dispatchPrecondition(condition: .onQueue(queue))
            guard port == nil else { return }
            guard let port = IONotificationPortCreate(kIOMainPortDefault) else {
                fail("Unable to create the USB notification port.")
                return
            }
            self.port = port
            IONotificationPortSetDispatchQueue(port, queue)
            let context = Unmanaged.passUnretained(self).toOpaque()

            // Register removal first so a device disappearing during enumeration is not lost.
            // Each registration consumes its own matching dictionary.
            guard let removalMatch = IOServiceMatching("IOUSBHostDevice") else {
                fail("Unable to create the USB matching dictionary.")
                return
            }
            let removalResult = IOServiceAddMatchingNotification(
                port, kIOTerminatedNotification, removalMatch,
                { context, iterator in
                    guard let context else { return }
                    Unmanaged<Worker>.fromOpaque(context).takeUnretainedValue()
                        .drain(iterator, connected: false)
                }, context, &removedIterator
            )
            guard removalResult == KERN_SUCCESS else {
                fail("USB removal notification registration failed (\(removalResult)).")
                return
            }
            drain(removedIterator, connected: false)

            guard let arrivalMatch = IOServiceMatching("IOUSBHostDevice") else {
                fail("Unable to create the USB matching dictionary.")
                return
            }
            let arrivalResult = IOServiceAddMatchingNotification(
                port, kIOFirstMatchNotification, arrivalMatch,
                { context, iterator in
                    guard let context else { return }
                    Unmanaged<Worker>.fromOpaque(context).takeUnretainedValue()
                        .drain(iterator, connected: true)
                }, context, &addedIterator
            )
            guard arrivalResult == KERN_SUCCESS else {
                fail("USB arrival notification registration failed (\(arrivalResult)).")
                return
            }
            isMonitoring = true
            debugLog("Monitoring started")
            // The initial iterator supplies existing devices and must be drained to arm notifications.
            drain(addedIterator, connected: true)
            publish()
        }

        func stop() {
            dispatchPrecondition(condition: .onQueue(queue))
            let wasMonitoring = isMonitoring
            isMonitoring = false
            if let port {
                IONotificationPortSetDispatchQueue(port, nil)
            }
            if addedIterator != 0 {
                IOObjectRelease(addedIterator)
                addedIterator = 0
            }
            if removedIterator != 0 {
                IOObjectRelease(removedIterator)
                removedIterator = 0
            }
            if let port {
                IONotificationPortDestroy(port)
                self.port = nil
            }
            devices.removeAll()
            if wasMonitoring {
                debugLog("Monitoring stopped")
                publish()
            }
        }

        private func drain(_ iterator: io_iterator_t, connected: Bool) {
            dispatchPrecondition(condition: .onQueue(queue))
            // Process pending arrivals before removals even if callback delivery is reordered.
            if !connected && addedIterator != 0 {
                drain(addedIterator, connected: true)
            }
            var changed = false
            // This drains a finite notification batch; it is not a polling loop.
            while case let service = IOIteratorNext(iterator), service != 0 {
                defer { IOObjectRelease(service) }
                var registryID: UInt64 = 0
                let result = IORegistryEntryGetRegistryEntryID(service, &registryID)
                guard result == KERN_SUCCESS else {
                    debugLog("Could not read a USB registry entry ID (\(result)).")
                    continue
                }
                if connected {
                    guard devices[registryID] == nil else { continue }
                    let device = readDevice(service, registryID: registryID)
                    devices[registryID] = device
                    log(device, connected: true)
                    changed = true
                } else if let device = devices.removeValue(forKey: registryID) {
                    // Cached properties remain available even after the service has terminated.
                    log(device, connected: false)
                    changed = true
                }
            }
            if changed && isMonitoring { publish() }
        }

        private func readDevice(_ service: io_service_t, registryID: UInt64) -> USBDevice {
            func property(_ key: String) -> Any? {
                IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
                    .takeRetainedValue()
            }
            func string(_ key: String) -> String? {
                guard let value = property(key) as? String else { return nil }
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
            func identifier(_ key: String) -> UInt16? {
                guard let number = property(key) as? NSNumber else { return nil }
                return UInt16(exactly: number.int64Value)
            }
            return USBDevice(
                registryEntryID: registryID,
                name: string(kUSBProductString) ?? "Unnamed USB Device",
                vendorID: identifier(kUSBVendorID),
                productID: identifier(kUSBProductID),
                serialNumber: string(kUSBSerialNumberString)
            )
        }

        private func publish(error: String? = nil) {
            let sorted = devices.values.sorted {
                if $0.name == $1.name { return $0.id < $1.id }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            continuation.yield(Snapshot(devices: sorted, isMonitoring: isMonitoring, error: error))
        }

        private func fail(_ message: String) {
            stop()
            debugLog(message)
            publish(error: message)
        }

        private func log(_ device: USBDevice, connected: Bool) {
            debugLog("\(connected ? "Connected" : "Disconnected"): \(device.name) (VID: \(device.vendorIDText), PID: \(device.productIDText))")
        }

        private func debugLog(_ message: String) {
            #if DEBUG
            print("[USB] \(message)")
            #endif
        }
    }
}
