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
                Text(selection?.name ?? "Select Application…")
                    .lineLimit(1)
            }
        }
        .buttonStyle(.borderless)
        .help("Select an application; changes apply on the next connection.")
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
