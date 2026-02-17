import Foundation
import SwiftUI

@MainActor
final class CleanerViewModel: ObservableObject {
    private enum StatsKey {
        static let allTimeSavedBytes = "cachify.all_time_saved_bytes"
        static let lastSavedBytes = "cachify.last_saved_bytes"
    }

    @Published var selectedTargetIDs: Set<String> = Set(allTargets.map(\.id))
    @Published var scanEntries: [ScanEntry] = []
    @Published var selectedEntryIDs: Set<UUID> = []
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var status = "Ready"
    @Published var showConfirmAlert = false
    @Published var hasScanned = false
    @Published var savedNowBytes: Int64
    @Published var allTimeSavedBytes: Int64
    @Published var hasFolderAccess = false
    @Published var folderAccessPath: String?
    @Published private(set) var lastNonEmptyScanEntries: [ScanEntry] = []
    @Published private(set) var hasCleanedInSession = false

    private let cleaner = CacheCleaner()
    private let folderAccessManager = FolderAccessManager()
    private let defaults = UserDefaults.standard

    init() {
        self.savedNowBytes = defaults.object(forKey: StatsKey.lastSavedBytes) as? Int64 ?? 0
        self.allTimeSavedBytes = defaults.object(forKey: StatsKey.allTimeSavedBytes) as? Int64 ?? 0
        self.hasFolderAccess = folderAccessManager.hasAccess
        self.folderAccessPath = folderAccessManager.folderPath
        if let folderAccessPath {
            Task { await cleaner.setHomePath(folderAccessPath) }
        }
    }

    var scopedEntries: [ScanEntry] {
        scanEntries.filter { selectedTargetIDs.contains($0.targetID) }
    }

    var selectedEntriesForCleaning: [ScanEntry] {
        scopedEntries.filter { selectedEntryIDs.contains($0.id) }
    }

    var selectedTargets: [CacheTarget] {
        allTargets.filter { selectedTargetIDs.contains($0.id) }
    }

    var totalBytes: Int64 {
        scopedEntries.reduce(0) { $0 + $1.size }
    }

    var selectedCleanBytes: Int64 {
        selectedEntriesForCleaning.reduce(0) { $0 + $1.size }
    }

    var canScan: Bool {
        !selectedTargets.isEmpty && !isScanning && !isCleaning
    }

    var canClean: Bool {
        !selectedEntriesForCleaning.isEmpty && !isScanning && !isCleaning
    }

    var targetSummaries: [TargetSummary] {
        summaries(from: scopedEntries)
    }

    var displayedTargetSummaries: [TargetSummary] {
        if !targetSummaries.isEmpty {
            return targetSummaries
        }
        return summaries(from: lastNonEmptyScanEntries)
    }

    var displayedTotalBytes: Int64 {
        let current = totalBytes
        if current > 0 {
            return current
        }
        return lastNonEmptyScanEntries.reduce(0) { $0 + $1.size }
    }

    var isShowingSnapshotData: Bool {
        totalBytes == 0 && !lastNonEmptyScanEntries.isEmpty
    }

    var targetSizesByID: [String: Int64] {
        Dictionary(grouping: scanEntries, by: \.targetID)
            .mapValues { entries in entries.reduce(0) { $0 + $1.size } }
    }

    var sortedTargets: [CacheTarget] {
        let order = Dictionary(uniqueKeysWithValues: allTargets.enumerated().map { ($1.id, $0) })
        return allTargets.sorted { lhs, rhs in
            let lhsSize = targetSizesByID[lhs.id] ?? 0
            let rhsSize = targetSizesByID[rhs.id] ?? 0
            if lhsSize != rhsSize {
                return lhsSize > rhsSize
            }
            return (order[lhs.id] ?? 0) < (order[rhs.id] ?? 0)
        }
    }

    func selectAll() {
        selectedTargetIDs = Set(allTargets.map(\.id))
    }

    func clearSelection() {
        selectedTargetIDs.removeAll()
    }

    func setTargetSelection(targetID: String, isOn: Bool) {
        if isOn {
            selectedTargetIDs.insert(targetID)
        } else {
            selectedTargetIDs.remove(targetID)
        }
    }

    func targetSize(for targetID: String) -> Int64 {
        targetSizesByID[targetID] ?? 0
    }

    func target(for targetID: String) -> CacheTarget? {
        allTargets.first { $0.id == targetID }
    }

    func entries(for targetID: String) -> [ScanEntry] {
        scanEntries
            .filter { $0.targetID == targetID }
            .sorted { $0.size > $1.size }
    }

    func isEntrySelected(_ entry: ScanEntry) -> Bool {
        selectedEntryIDs.contains(entry.id)
    }

    func setEntrySelection(entry: ScanEntry, isOn: Bool) {
        if isOn {
            selectedEntryIDs.insert(entry.id)
        } else {
            selectedEntryIDs.remove(entry.id)
        }
    }

    func handleOnAppear() {
        if hasFolderAccess {
            scan()
        } else {
            status = "Grant Home folder access to scan caches in the exported app."
        }
    }

    func requestFolderAccess() {
        status = "Opening folder picker..."
        Task {
            switch await folderAccessManager.requestHomeFolderAccess() {
            case .granted(let path):
                hasFolderAccess = true
                folderAccessPath = path
                await cleaner.setHomePath(path)
                status = "Access granted for \(path). Scanning..."
                scan()
            case .cancelled:
                status = "Folder access canceled."
            case .failed:
                status = "Failed to store folder access permission."
            }
        }
    }

    func scan() {
        guard !selectedTargets.isEmpty else {
            status = "Select at least one target"
            return
        }
        guard hasFolderAccess else {
            status = "Grant Home folder access first."
            return
        }

        isScanning = true
        status = "Scanning cache paths..."
        let targets = selectedTargets

        Task {
            guard let results = await folderAccessManager.withSecurityScopedAccess({
                await cleaner.scan(targets: targets)
            }) else {
                self.isScanning = false
                self.status = "Unable to access selected folder."
                return
            }

            // Update only the targets being scanned so a narrow scan (e.g. Docker only)
            // does not wipe previously discovered entries from other targets.
            let scannedTargetIDs = Set(targets.map(\.id))
            let untouchedEntries = self.scanEntries.filter { !scannedTargetIDs.contains($0.targetID) }
            self.scanEntries = (untouchedEntries + results).sorted { $0.size > $1.size }

            let untouchedSelectedIDs = Set(
                untouchedEntries
                    .filter { self.selectedEntryIDs.contains($0.id) }
                    .map(\.id)
            )
            self.selectedEntryIDs = untouchedSelectedIDs.union(Set(results.map(\.id)))

            if !results.isEmpty {
                self.lastNonEmptyScanEntries = self.scanEntries
            }
            self.hasScanned = true
            self.isScanning = false
            self.status = results.isEmpty ? "No cache found for selected targets" : "Found \(results.count) cache path(s)"
        }
    }

    func requestClean() {
        guard canClean else { return }
        showConfirmAlert = true
    }

    func clean() {
        guard canClean else { return }
        guard hasFolderAccess else {
            status = "Grant Home folder access first."
            return
        }

        isCleaning = true
        status = "Cleaning selected caches..."
        let entries = selectedEntriesForCleaning

        Task {
            let result = await self.performClean(entries: entries)
            guard result != nil else { return }
            self.scan()
        }
    }

    func clean(entries: [ScanEntry]) {
        guard !entries.isEmpty else { return }
        guard !isScanning && !isCleaning else { return }
        guard hasFolderAccess else {
            status = "Grant Home folder access first."
            return
        }

        isCleaning = true
        status = "Cleaning selected caches..."

        Task {
            _ = await self.performClean(entries: entries)
        }
    }

    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: bytes)
    }

    func style(for targetID: String) -> TargetStyle {
        targetStyles[targetID] ?? TargetStyle(color: .gray, icon: "externaldrive")
    }

    private func performClean(entries: [ScanEntry]) async -> (removed: Int, failed: Int, reclaimedBytes: Int64, removedEntryIDs: Set<UUID>)? {
        guard let result = await folderAccessManager.withSecurityScopedAccess({
            await cleaner.clean(entries: entries)
        }) else {
            self.isCleaning = false
            self.status = "Unable to access selected folder."
            return nil
        }

        self.scanEntries.removeAll { result.removedEntryIDs.contains($0.id) }
        self.selectedEntryIDs.subtract(result.removedEntryIDs)
        self.savedNowBytes = result.reclaimedBytes
        self.allTimeSavedBytes += result.reclaimedBytes
        self.hasCleanedInSession = true
        self.defaults.set(self.savedNowBytes, forKey: StatsKey.lastSavedBytes)
        self.defaults.set(self.allTimeSavedBytes, forKey: StatsKey.allTimeSavedBytes)
        self.isCleaning = false
        self.status = "Removed \(result.removed) path(s), failed \(result.failed), reclaimed \(self.formatBytes(result.reclaimedBytes))"
        return result
    }

    private func summaries(from entries: [ScanEntry]) -> [TargetSummary] {
        let grouped = Dictionary(grouping: entries, by: \.targetID)
            .mapValues { items in items.reduce(0) { $0 + $1.size } }

        return allTargets.compactMap { target in
            guard let size = grouped[target.id], size > 0 else { return nil }
            return TargetSummary(id: target.id, target: target, size: size)
        }
        .sorted { $0.size > $1.size }
    }
}
