import Foundation
import Observation
import ServiceManagement

/// Owns only service registration. It never starts an automation controller.
@MainActor
@Observable
final class HelperRegistrationManager {
    static let shared = HelperRegistrationManager()
    private(set) var status: HelperRegistrationStatus?
    private(set) var isBusy = false
    private(set) var hasBundledService = false
    private(set) var errorMessage: String?
    private(set) var message: String?
    @ObservationIgnored private let service = HelperService()

    var canRegister: Bool {
        !isBusy && hasBundledService && (status == .notRegistered || status == .notFound)
    }
    var canUnregister: Bool { !isBusy && (status == .enabled || status == .requiresApproval) }

    func refresh() async {
        guard !isBusy else { return }
        isBusy = true
        hasBundledService = await service.hasBundledService()
        status = await service.status()
        isBusy = false
        #if DEBUG
        print("[Service] Registration status: \(status?.title ?? "Unknown")")
        #endif
    }

    func register() async {
        guard canRegister else { return }
        isBusy = true
        errorMessage = nil
        message = nil
        do {
            try await service.register()
            message = "Registration requested. Eligibility does not confirm that the Helper is running or owns automation."
        } catch {
            errorMessage = "Could not register the Helper: \(error.localizedDescription)"
        }
        // Never synthesize success or reset state after a failed operation.
        hasBundledService = await service.hasBundledService()
        status = await service.status()
        isBusy = false
    }

    /// Called only after the view's explicit confirmation.
    func unregister() async {
        guard canUnregister else { return }
        isBusy = true
        errorMessage = nil
        message = nil
        do {
            try await service.unregister()
            message = "ServiceManagement completed unregistration and stopping its managed service. Independently started Xcode Helpers are not covered; stop those in Xcode if needed."
        } catch {
            errorMessage = "Could not unregister the Helper: \(error.localizedDescription)"
        }
        hasBundledService = await service.hasBundledService()
        status = await service.status()
        isBusy = false
    }

    func openSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

nonisolated enum HelperRegistrationStatus: Sendable {
    case notRegistered, enabled, requiresApproval, notFound, unknown

    var title: String {
        switch self {
        case .notRegistered: "Not Registered"
        case .enabled: "Enabled"
        case .requiresApproval: "Requires Approval"
        case .notFound: "Not Found"
        case .unknown: "Unknown"
        }
    }

    var guidance: String {
        switch self {
        case .notRegistered: "Register to enable the background service and startup at login."
        case .enabled: "The service is registered and eligible to run. Process activity is not independently verified."
        case .requiresApproval: "Allow USB App Launcher in System Settings → General → Login Items (background activity), then return here."
        case .notFound: "macOS could not find a service registration. If Register is available, you can request registration. Otherwise rebuild or reopen a complete app bundle."
        case .unknown: "macOS returned an unrecognized service status. No registration changes were made."
        }
    }
}

/// Serializes ServiceManagement work away from the main actor. No polling.
private actor HelperService {
    private let service = SMAppService.agent(plistName: "com.ssy523a.USBAppLauncher.Helper.plist")

    func status() -> HelperRegistrationStatus {
        switch service.status {
        case .notRegistered: .notRegistered
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        case .notFound: .notFound
        @unknown default: .unknown
        }
    }

    func hasBundledService() -> Bool {
        let bundle = Bundle.main.bundleURL
        let plist = bundle.appendingPathComponent("Contents/Library/LaunchAgents/com.ssy523a.USBAppLauncher.Helper.plist")
        let executable = bundle.appendingPathComponent("Contents/Helpers/USBAppLauncherHelper")
        return FileManager.default.isReadableFile(atPath: plist.path)
            && FileManager.default.isExecutableFile(atPath: executable.path)
    }

    func register() throws { try service.register() }

    func unregister() async throws {
        // The asynchronous API completes after the managed process has stopped,
        // unlike the synchronous variant. It is then safe to register again.
        try await service.unregister()
    }
}
