import AppKit
import Foundation

@MainActor
final class FolderAccessManager {
    enum RequestResult {
        case granted(path: String)
        case cancelled
        case failed
    }

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

    func requestHomeFolderAccess() async -> RequestResult {
        let panel = NSOpenPanel()
        panel.title = "Grant Folder Access"
        panel.message = "Select the folder Cachify should scan for caches (your Home folder is recommended)."
        panel.prompt = "Grant Access"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.directoryURL = preferredUserHomeURL()

        let response: NSApplication.ModalResponse
        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            response = await withCheckedContinuation { continuation in
                panel.beginSheetModal(for: window) { modalResponse in
                    continuation.resume(returning: modalResponse)
                }
            }
        } else {
            response = panel.runModal()
        }

        guard response == .OK, let selected = panel.url else {
            return .cancelled
        }

        guard saveBookmark(for: selected) else {
            return .failed
        }

        folderURL = selected
        return .granted(path: selected.path)
    }

    func withSecurityScopedAccess<T>(_ work: () async -> T) async -> T? {
        guard let folderURL else { return nil }
        let started = folderURL.startAccessingSecurityScopedResource()
        guard started else { return nil }
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

            if isLikelySandboxContainer(url.path) {
                defaults.removeObject(forKey: StorageKey.homeFolderBookmark)
                return nil
            }

            return url
        } catch {
            defaults.removeObject(forKey: StorageKey.homeFolderBookmark)
            return nil
        }
    }

    private func preferredUserHomeURL() -> URL {
        let username = NSUserName()
        if let path = NSHomeDirectoryForUser(username),
           !path.isEmpty {
            return URL(fileURLWithPath: path)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    private func isLikelySandboxContainer(_ path: String) -> Bool {
        let runtimeHome = NSHomeDirectory()
        let username = NSUserName()
        let realHome = NSHomeDirectoryForUser(username) ?? runtimeHome

        let looksLikeContainer = runtimeHome.contains("/Library/Containers/")
        let pointsToRuntimeHome = path == runtimeHome
        let differsFromRealHome = runtimeHome != realHome

        return looksLikeContainer && pointsToRuntimeHome && differsFromRealHome
    }
}
