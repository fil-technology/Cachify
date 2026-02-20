import AppKit
import Foundation
import Darwin

@MainActor
final class FolderAccessManager {
    struct AccessScopeResult<T> {
        let value: T
        let startedSecurityScope: Bool
        let path: String
    }

    enum RequestResult {
        case granted(path: String)
        case cancelled
        case wrongFolder(expected: String, selected: String)
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

    var debugContext: String {
        let runtimeHome = NSHomeDirectory()
        let realHome = NSHomeDirectoryForUser(NSUserName()) ?? "n/a"
        let selected = folderURL?.path ?? "none"
        return "selected=\(selected), runtimeHome=\(runtimeHome), realHome=\(realHome)"
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

        let expectedHome = realUserHomePath()
        guard selected.path == expectedHome else {
            return .wrongFolder(expected: expectedHome, selected: selected.path)
        }

        guard saveBookmark(for: selected) else {
            return .failed
        }

        folderURL = selected
        return .granted(path: selected.path)
    }

    func withSecurityScopedAccess<T>(_ work: () async -> T) async -> AccessScopeResult<T>? {
        guard let folderURL else { return nil }
        let started = folderURL.startAccessingSecurityScopedResource()
        defer {
            if started {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }
        let value = await work()
        return AccessScopeResult(value: value, startedSecurityScope: started, path: folderURL.path)
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

            if isLikelySandboxContainer(url.path) || !isRealHomePath(url.path) {
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
        URL(fileURLWithPath: realUserHomePath())
    }

    private func realUserHomePath() -> String {
        if let path = posixUserHomePath(), !path.isEmpty {
            return path
        }

        let runtime = NSHomeDirectory()
        if let unsandboxed = unsandboxedHomePath(from: runtime) {
            return unsandboxed
        }

        let username = NSUserName()
        if let path = NSHomeDirectoryForUser(username), !path.isEmpty {
            if let unsandboxed = unsandboxedHomePath(from: path) {
                return unsandboxed
            }
            return path
        }

        return FileManager.default.homeDirectoryForCurrentUser.path
    }

    private func isRealHomePath(_ path: String) -> Bool {
        path == realUserHomePath()
    }

    private func isLikelySandboxContainer(_ path: String) -> Bool {
        let runtimeHome = NSHomeDirectory()
        let realHome = realUserHomePath()

        let looksLikeContainer = runtimeHome.contains("/Library/Containers/")
        let pointsToRuntimeHome = path == runtimeHome
        let differsFromRealHome = runtimeHome != realHome

        return looksLikeContainer && pointsToRuntimeHome && differsFromRealHome
    }

    private func posixUserHomePath() -> String? {
        guard let pw = getpwuid(getuid()), let home = pw.pointee.pw_dir else {
            return nil
        }
        return String(cString: home)
    }

    private func unsandboxedHomePath(from path: String) -> String? {
        let marker = "/Library/Containers/"
        guard let markerRange = path.range(of: marker) else {
            return nil
        }
        let prefix = String(path[..<markerRange.lowerBound])
        if prefix.hasPrefix("/Users/"), prefix.split(separator: "/").count >= 2 {
            return prefix
        }
        return nil
    }
}
