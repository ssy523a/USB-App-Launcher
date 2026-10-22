import AppKit
import SwiftUI

struct ApplicationSelectionCell: View {
    let selection: SelectedApplication?
    let select: () -> Void
    @State private var icon: NSImage?

    var body: some View {
        Button(action: select) {
            HStack(spacing: 6) {
                if let icon {
                    Image(nsImage: icon).resizable().frame(width: 18, height: 18)
                }
                Text(selection?.name ?? "Choose App...")
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .buttonStyle(.borderless)
        .help(selection.map { "\($0.name) — Select to replace this application." } ?? "Choose an application.")
        .task(id: selection) {
            icon = nil
            guard let selection else { return }
            let path = await Task.detached(priority: .utility) {
                (try? selection.resolve().path) ?? selection.path
            }.value
            guard !Task.isCancelled else { return }
            icon = NSWorkspace.shared.icon(forFile: path)
        }
    }
}
