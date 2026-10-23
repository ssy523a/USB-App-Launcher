import AppKit
import SwiftUI

struct AboutView: View {
    private var version: String {
        let value = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return value?.isEmpty == false ? value ?? "" : "Unavailable"
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .accessibilityLabel("USB App Launcher icon")
            VStack(spacing: 4) {
                Text("USB App Launcher").font(.title2.bold())
                Text("Version \(version)").foregroundStyle(.secondary)
            }
            .textSelection(.enabled)
            VStack(spacing: 6) {
                Text("Developer: Seo, Se-young").textSelection(.enabled)
                if let emailURL = URL(string: "mailto:ssy523a@gmail.com") {
                    Link("ssy523a@gmail.com", destination: emailURL)
                        .accessibilityLabel("Email Seo, Se-young: ssy523a@gmail.com")
                }
            }
        }
        .padding(28)
        .frame(width: 360)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct AboutCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About USB App Launcher") {
                openWindow(id: "about")
            }
        }
    }
}
