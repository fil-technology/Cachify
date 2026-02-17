import AppKit
import Foundation

@MainActor
final class FolderAccessManager {
    private enum StorageKey {
        static let homeFolderBookmark = "cachify.home_folder_bookmark"
    }

    private let defaults = UserDefaults.standard
    private(set) var folderURL: URL?

    init() {
        self.folderURL = loadBookmarkURL()
    }

    var hasAccess: Bool {
        folderURL != nil
    }

    var folderPath: String? {
        folderURL?.path
    }

    func requestHomeFolderAccess() -> Bool {
        let panel = NSOpenPanel()
        panel.title = "Grant Folder Access"
        panel.message = "Select your home folder so Cachify can scan cache directories in sandbox mode."
        panel.prompt = "Grant Access"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser

        guard panel.runModal() == .OK, let selected = panel.url else {
            return false
        }

        guard saveBookmark(for: selected) else {
            return false
        }

        folderURL = selected
        return true
    }

    func withSecurityScopedAccess<T>(_ work: () async -> T) async -> T? {
        guard let folderURL else { return nil }
        let started = folderURL.startAccessingSecurityScopedResource()
        defer {
            if started {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }
        return await work()
    }

    private func saveBookmark(for url: URL) -> Bool {
        do {
            let bookmark = try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
            defaults.set(bookmark, forKey: StorageKey.homeFolderBookmark)
            return true
        } catch {
            return false
        }
    }

    private func loadBookmarkURL() -> URL? {
        guard let data = defaults.data(forKey: StorageKey.homeFolderBookmark) else {
            return nil
        }

        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                _ = saveBookmark(for: url)
            }

            return url
        } catch {
            defaults.removeObject(forKey: StorageKey.homeFolderBookmark)
            return nil
        }
    }
}
