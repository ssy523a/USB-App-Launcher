import Darwin
import Dispatch

/// The main dispatch queue serializes signal delivery and orderly shutdown.
/// No USB, application automation, configuration reads, or UI are started here.
final class HelperLifecycle {
    private var signalSources: [DispatchSourceSignal] = []
    private let cancellationGroup = DispatchGroup()
    private var isStopping = false

    func start() {
        for number in [SIGTERM, SIGINT] {
            // Dispatch sources observe signals; ignoring the default action lets
            // the source perform cleanup instead of immediate process termination.
            signal(number, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: number, queue: .main)
            cancellationGroup.enter()
            source.setEventHandler { [weak self] in
                self?.stop()
            }
            let group = cancellationGroup
            source.setCancelHandler { group.leave() }
            signalSources.append(source)
            source.activate()
        }
        debugLog("USB App Launcher Helper started")
    }

    private func stop() {
        guard !isStopping else { return }
        isStopping = true
        debugLog("Shutdown requested")
        for source in signalSources { source.cancel() }
        signalSources.removeAll()
        // Wait asynchronously until both sources have completed cancellation.
        cancellationGroup.notify(queue: .main) {
            debugLog("Stopped")
            exit(EXIT_SUCCESS)
        }
    }
}

private func debugLog(_ message: String) {
    #if DEBUG
    print("[Helper] \(message)")
    fflush(stdout)
    #endif
}

// Keep the lifecycle alive for the process lifetime. dispatchMain sleeps in the
// system event machinery when idle; it does not poll or create a recurring timer.
let lifecycle = HelperLifecycle()
lifecycle.start()
dispatchMain()
