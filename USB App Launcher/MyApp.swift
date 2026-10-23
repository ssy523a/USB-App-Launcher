import AppKit
import SwiftUI

@main
struct MyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("USB App Launcher", id: "usb-monitor") {
            ContentView(model: appDelegate.model)
                .background(MainWindowCloseHandler(appDelegate: appDelegate))
        }
        .defaultSize(width: 960, height: 580)
        .windowResizability(.contentMinSize)
        .commands {
            AboutCommands()
            CommandGroup(after: .newItem) {
                Button("Close Window") {
                    NSApplication.shared.sendAction(#selector(NSWindow.performClose(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("w", modifiers: .command)
            }
        }

        Window("About USB App Launcher", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .commandsRemoved()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = USBMonitorViewModel()
    private var terminationRequested = false

    func observeMainWindow(_ window: NSWindow) {
        NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(mainWindowWillClose(_:)),
            name: NSWindow.willCloseNotification, object: window
        )
    }

    @objc private func mainWindowWillClose(_ notification: Notification) {
        guard !terminationRequested else { return }
        // Use the run loop: terminateLater must be able to drain MainActor work.
        // Calling terminate inside a main-dispatch block can stall that teardown.
        NSApplication.shared.perform(#selector(NSApplication.terminate(_:)), with: nil, afterDelay: 0)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        model.start()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !terminationRequested else { return .terminateLater }
        terminationRequested = true
        // Wait asynchronously for IOKit teardown without blocking the main thread.
        Task {
            await model.stop()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Closing About (even as the last window) must not quit the app.
        false
    }
}

/// Observes only the window containing the management scene, without replacing
/// SwiftUI's window delegate or observing auxiliary windows.
private struct MainWindowCloseHandler: NSViewRepresentable {
    let appDelegate: AppDelegate

    func makeNSView(context: Context) -> WindowAttachmentView {
        let view = WindowAttachmentView()
        view.appDelegate = appDelegate
        return view
    }

    func updateNSView(_ nsView: WindowAttachmentView, context: Context) {}

    final class WindowAttachmentView: NSView {
        weak var appDelegate: AppDelegate?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            // The app delegate retains observation through SwiftUI view teardown.
            appDelegate?.observeMainWindow(window)
        }
    }
}
