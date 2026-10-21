import Foundation

/// User-selected bundle identity, independent of any running process.
nonisolated struct SelectedApplication: Codable, Equatable, Sendable {
    let bundleIdentifier: String?
    let path: String
    let name: String
    let bookmark: Data?

    var key: String { bundleIdentifier.map { "bundle:" + $0 } ?? "path:" + path }

    static func select(_ url: URL) throws -> Self {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let canonical = url.resolvingSymlinksInPath().standardizedFileURL
        let bundle = try validatedBundle(canonical)
        // This app is deliberately unsandboxed. Ordinary bookmarks track moves
        // without granting additional access or requiring bookmark entitlements.
        let bookmark = try canonical.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        return Self(bundleIdentifier: bundle.bundleIdentifier, path: canonical.path,
                    name: (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                        ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                        ?? canonical.deletingPathExtension().lastPathComponent,
                    bookmark: bookmark)
    }

    func resolve() throws -> URL {
        let url: URL
        if let bookmark {
            var stale = false
            url = try URL(resolvingBookmarkData: bookmark, options: [.withoutUI, .withoutMounting],
                          relativeTo: nil, bookmarkDataIsStale: &stale)
            guard !stale else { throw SelectionError.reselect }
        } else {
            url = URL(fileURLWithPath: path)
        }
        let canonical = url.resolvingSymlinksInPath().standardizedFileURL
        let bundle = try Self.validatedBundle(canonical)
        guard bundle.bundleIdentifier == bundleIdentifier else { throw SelectionError.reselect }
        return canonical
    }

    private static func validatedBundle(_ url: URL) throws -> Bundle {
        guard url.isFileURL, url.pathExtension.lowercased() == "app",
              let bundle = Bundle(url: url),
              bundle.object(forInfoDictionaryKey: "CFBundlePackageType") as? String == "APPL",
              let executable = bundle.executableURL,
              FileManager.default.isExecutableFile(atPath: executable.path)
        else { throw SelectionError.reselect }
        return bundle
    }

    enum SelectionError: LocalizedError {
        case reselect
        var errorDescription: String? {
            "The selected application is missing, inaccessible, changed, or has a stale bookmark. Please select it again."
        }
    }
}
