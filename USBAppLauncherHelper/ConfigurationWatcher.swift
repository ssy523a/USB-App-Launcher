import Darwin
import Dispatch
import Foundation

/// All mutable state and disk work belongs to queue. Events are delivered in read order.
/// The directory survives atomic file replacement; the file source covers in-place edits.
nonisolated final class ConfigurationWatcher: @unchecked Sendable {
    enum Event: Sendable {
        case rules([RegisteredUSBDevice])
        case invalid
        case unavailable
    }

    let events: AsyncStream<Event>
    private let continuation: AsyncStream<Event>.Continuation
    private let url: URL
    private let queue = DispatchQueue(label: "USBAppLauncher.configuration", qos: .utility)
    private let cancellations = DispatchGroup()
    private var directorySource: DispatchSourceFileSystemObject?
    private var fileSource: DispatchSourceFileSystemObject?
    private var started = false
    private var stopped = false
    private var lastBytes: Data?
    private var lastRules: [RegisteredUSBDevice]?
    private var invalid = false

    init(url: URL) {
        self.url = url
        let stream = AsyncStream<Event>.makeStream()
        events = stream.stream
        continuation = stream.continuation
    }

    func start() {
        queue.async { [self] in
            guard !started, !stopped else { return }
            started = true
            directorySource = source(for: url.deletingLastPathComponent(), directory: true)
            guard directorySource != nil else {
                continuation.yield(.unavailable)
                return
            }
            refresh()
        }
    }

    private func source(for path: URL, directory: Bool) -> DispatchSourceFileSystemObject? {
        let fd = open(path.path, O_EVTONLY | O_CLOEXEC | O_NOFOLLOW)
        guard fd >= 0 else { return nil }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: [.write, .extend, .attrib, .rename, .delete, .revoke],
            queue: queue
        )
        cancellations.enter()
        let group = cancellations
        source.setCancelHandler { close(fd); group.leave() }
        source.setEventHandler { [weak self, weak source] in
            guard let self, !stopped, let source else { return }
            if directory && !source.data.intersection([.rename, .delete, .revoke]).isEmpty {
                // Replacing the whole directory also invalidates the lease's inode domain.
                // Do not silently follow it and continue automation.
                continuation.yield(.unavailable)
                return
            }
            refresh()
        }
        source.activate()
        return source
    }

    private func refresh() {
        guard !stopped else { return }
        // Reopen by pathname before reading, so a new inode is observed after replacement.
        fileSource?.cancel()
        fileSource = source(for: url, directory: false)
        do {
            let bytes = try Data(contentsOf: url)
            guard bytes != lastBytes || invalid else { return }
            let rules = try USBRegistrationStore.decode(bytes)
            lastBytes = bytes
            let recovered = invalid
            invalid = false
            if rules != lastRules || recovered {
                lastRules = rules
                continuation.yield(.rules(rules))
            }
        } catch {
            // A missing/invalid file is never an empty list. Preserve the last valid data.
            if !invalid { continuation.yield(.invalid) }
            invalid = true
        }
    }

    func stop() async {
        await withCheckedContinuation { completion in
            queue.async { [self] in
                stopped = true
                directorySource?.cancel()
                fileSource?.cancel()
                directorySource = nil
                fileSource = nil
                continuation.finish()
                cancellations.notify(queue: queue) { completion.resume() }
            }
        }
    }

    deinit {
        directorySource?.cancel()
        fileSource?.cancel()
        continuation.finish()
    }
}
