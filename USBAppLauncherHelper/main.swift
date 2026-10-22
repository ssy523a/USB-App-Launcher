import CoreFoundation
import Darwin
import Dispatch
import Foundation

@MainActor
final class HelperLifecycle {
    private var signalSources: [DispatchSourceSignal] = []
    private let cancellationGroup = DispatchGroup()
    private var isStopping = false
    private var controller: HelperAutomationController?
    private var startupTask: Task<Void, Never>?
    private var keepAliveSource: CFRunLoopSource?

    func start() {
        // Keep the actual main thread's run loop alive for NSWorkspace callbacks.
        // This source is never signalled and produces no recurring work.
        var context = CFRunLoopSourceContext()
        guard let source = CFRunLoopSourceCreate(nil, 0, &context) else { exit(EXIT_FAILURE) }
        keepAliveSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        for number in [SIGTERM, SIGINT] {
            signal(number, SIG_IGN)
            let signalSource = DispatchSource.makeSignalSource(signal: number, queue: .main)
            cancellationGroup.enter()
            signalSource.setEventHandler { [weak self] in
                Task { @MainActor [weak self] in await self?.stop() }
            }
            let group = cancellationGroup
            signalSource.setCancelHandler { group.leave() }
            signalSources.append(signalSource)
            signalSource.activate()
        }
        debugLog("USB App Launcher Helper started")
        if CommandLine.arguments.contains("--automation-test") {
            print("[Helper] Automation Test Mode requested; acquiring ownership")
            let controller = HelperAutomationController()
            self.controller = controller
            startupTask = Task { await controller.start() }
        } else {
            print("[Helper] Inactive Mode: automation disabled (use --automation-test explicitly)")
        }
    }

    private func stop() async {
        guard !isStopping else { return }
        isStopping = true
        debugLog("Shutdown requested")
        startupTask?.cancel()
        await controller?.stop()
        await startupTask?.value
        controller = nil
        for source in signalSources { source.cancel() }
        signalSources.removeAll()
        let source = keepAliveSource
        keepAliveSource = nil
        cancellationGroup.notify(queue: .main) {
            if let source { CFRunLoopSourceInvalidate(source) }
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

// This synchronous executable entry point runs on the OS main thread.
MainActor.assumeIsolated {
    let lifecycle = HelperLifecycle()
    lifecycle.start()
    withExtendedLifetime(lifecycle) { CFRunLoopRun() }
}
