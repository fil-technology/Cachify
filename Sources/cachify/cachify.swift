import Foundation
import SwiftUI

struct CacheTarget: Identifiable, Hashable {
    let id: String
    let name: String
    let details: String
    let patterns: [String]
}

struct ScanEntry: Identifiable {
    let id = UUID()
    let targetID: String
    let path: String
    let size: Int64
}

struct TargetSummary: Identifiable {
    let id: String
    let target: CacheTarget
    let size: Int64
}

struct PathCandidate {
    let targetID: String
    let path: String
}

struct TargetStyle {
    let color: Color
    let icon: String
}

let targetStyles: [String: TargetStyle] = [
    "xcode": TargetStyle(color: .blue, icon: "hammer.fill"),
    "ios-simulator": TargetStyle(color: .cyan, icon: "iphone.gen3"),
    "node": TargetStyle(color: .green, icon: "shippingbox.fill"),
    "python": TargetStyle(color: .orange, icon: "chevron.left.forwardslash.chevron.right"),
    "android-studio": TargetStyle(color: .mint, icon: "ladybug.fill"),
    "build-tools": TargetStyle(color: .pink, icon: "wrench.and.screwdriver.fill"),
    "docker": TargetStyle(color: .teal, icon: "shippingbox.circle.fill"),
    "java-kotlin": TargetStyle(color: .indigo, icon: "cup.and.saucer.fill"),
    "go-rust": TargetStyle(color: .brown, icon: "gearshape.2.fill"),
    "dotnet": TargetStyle(color: .purple, icon: "cube.box.fill"),
    "editors": TargetStyle(color: .yellow, icon: "pencil.and.outline"),
    "design-tools": TargetStyle(color: .red, icon: "paintpalette.fill"),
    "unity": TargetStyle(color: .gray, icon: "gamecontroller.fill"),
    "browsers": TargetStyle(color: .blue, icon: "globe")
]

actor CacheCleaner {
    private let fileManager = FileManager.default
    private let homePath: String

    init() {
        self.homePath = fileManager.homeDirectoryForCurrentUser.path
    }

    func scan(targets: [CacheTarget]) -> [ScanEntry] {
        let candidates = resolvePaths(for: targets)
        var results: [ScanEntry] = []

        for item in candidates {
            guard fileManager.fileExists(atPath: item.path) else {
                continue
            }
            let size = directorySize(at: item.path)
            if size > 0 {
                results.append(ScanEntry(targetID: item.targetID, path: item.path, size: size))
            }
        }

        return results.sorted { $0.size > $1.size }
    }

    func clean(entries: [ScanEntry]) -> (removed: Int, failed: Int, reclaimedBytes: Int64, removedEntryIDs: Set<UUID>) {
        var removed = 0
        var failed = 0
        var reclaimedBytes: Int64 = 0
        var removedEntryIDs = Set<UUID>()

        for entry in entries {
            guard isSafeToDelete(path: entry.path) else {
                failed += 1
                continue
            }

            do {
                try fileManager.removeItem(atPath: entry.path)
                removed += 1
                reclaimedBytes += entry.size
                removedEntryIDs.insert(entry.id)
            } catch {
                failed += 1
            }
        }

        return (removed, failed, reclaimedBytes, removedEntryIDs)
    }

    private func resolvePaths(for targets: [CacheTarget]) -> [PathCandidate] {
        var result: [PathCandidate] = []
        var seen = Set<String>()

        for target in targets {
            for pattern in target.patterns {
                for path in expand(pattern: pattern) {
                    if seen.insert(path).inserted {
                        result.append(PathCandidate(targetID: target.id, path: path))
                    }
                }
            }
        }

        return result.sorted { $0.path < $1.path }
    }

    private func expand(pattern: String) -> [String] {
        let expanded = (pattern as NSString).expandingTildeInPath
        if !expanded.contains("*") {
            return [expanded]
        }

        let segments = expanded.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        let isAbsolute = expanded.hasPrefix("/")
        var bases = [isAbsolute ? "/" : ""]

        for segment in segments where !segment.isEmpty {
            var next: [String] = []
            for base in bases {
                if segment.contains("*") {
                    let parent = base.isEmpty ? "." : base
                    guard let entries = try? fileManager.contentsOfDirectory(atPath: parent) else {
                        continue
                    }
                    for entry in entries where wildcardMatch(text: entry, pattern: segment) {
                        next.append(join(base: base, component: entry))
                    }
                } else {
                    next.append(join(base: base, component: segment))
                }
            }
            bases = next
        }

        return bases
    }

    private func join(base: String, component: String) -> String {
        if base.isEmpty {
            return component
        }
        if base == "/" {
            return "/" + component
        }
        return base + "/" + component
    }

    private func wildcardMatch(text: String, pattern: String) -> Bool {
        let textChars = Array(text)
        let patternChars = Array(pattern)

        var t = 0
        var p = 0
        var star = -1
        var match = 0

        while t < textChars.count {
            if p < patternChars.count, patternChars[p] == textChars[t] {
                t += 1
                p += 1
            } else if p < patternChars.count, patternChars[p] == "*" {
                star = p
                match = t
                p += 1
            } else if star != -1 {
                p = star + 1
                match += 1
                t = match
            } else {
                return false
            }
        }

        while p < patternChars.count, patternChars[p] == "*" {
            p += 1
        }

        return p == patternChars.count
    }

    private func directorySize(at path: String) -> Int64 {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return 0
        }

        if !isDirectory.boolValue {
            let attrs = (try? fileManager.attributesOfItem(atPath: path)) ?? [:]
            return (attrs[.size] as? NSNumber)?.int64Value ?? 0
        }

        var total: Int64 = 0
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey, .totalFileAllocatedSizeKey]

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: Array(keys),
            options: [],
            errorHandler: { _, _ in true }
        ) else {
            return 0
        }

        for case let fileURL as URL in enumerator {
            guard
                let values = try? fileURL.resourceValues(forKeys: keys),
                values.isRegularFile == true
            else {
                continue
            }

            if let allocated = values.totalFileAllocatedSize {
                total += Int64(allocated)
            } else if let fileSize = values.fileSize {
                total += Int64(fileSize)
            }
        }

        return total
    }

    private func isSafeToDelete(path: String) -> Bool {
        let expanded = (path as NSString).expandingTildeInPath
        if expanded == homePath {
            return false
        }
        return expanded.hasPrefix(homePath + "/")
    }
}

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

    private let cleaner = CacheCleaner()
    private let defaults = UserDefaults.standard

    init() {
        self.savedNowBytes = defaults.object(forKey: StatsKey.lastSavedBytes) as? Int64 ?? 0
        self.allTimeSavedBytes = defaults.object(forKey: StatsKey.allTimeSavedBytes) as? Int64 ?? 0
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
        let grouped = Dictionary(grouping: scopedEntries, by: \ .targetID)
            .mapValues { entries in entries.reduce(0) { $0 + $1.size } }

        return allTargets.compactMap { target in
            guard let size = grouped[target.id], size > 0 else { return nil }
            return TargetSummary(id: target.id, target: target, size: size)
        }
        .sorted { $0.size > $1.size }
    }

    var targetSizesByID: [String: Int64] {
        Dictionary(grouping: scanEntries, by: \.targetID)
            .mapValues { entries in entries.reduce(0) { $0 + $1.size } }
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

    func scan() {
        guard !selectedTargets.isEmpty else {
            status = "Select at least one target"
            return
        }

        isScanning = true
        status = "Scanning cache paths..."
        let targets = selectedTargets

        Task {
            let results = await cleaner.scan(targets: targets)
            self.scanEntries = results
            self.selectedEntryIDs = Set(results.map(\.id))
            self.hasScanned = true
            self.isScanning = false
            self.status = results.isEmpty ? "No cache found" : "Found \(results.count) cache path(s)"
        }
    }

    func requestClean() {
        guard canClean else { return }
        showConfirmAlert = true
    }

    func clean() {
        guard canClean else { return }

        isCleaning = true
        status = "Cleaning selected caches..."
        let entries = selectedEntriesForCleaning

        Task {
            let result = await cleaner.clean(entries: entries)
            self.scanEntries.removeAll { result.removedEntryIDs.contains($0.id) }
            self.selectedEntryIDs.subtract(result.removedEntryIDs)
            self.savedNowBytes = result.reclaimedBytes
            self.allTimeSavedBytes += result.reclaimedBytes
            self.defaults.set(self.savedNowBytes, forKey: StatsKey.lastSavedBytes)
            self.defaults.set(self.allTimeSavedBytes, forKey: StatsKey.allTimeSavedBytes)
            self.isCleaning = false
            self.status = "Removed \(result.removed) path(s), failed \(result.failed), reclaimed \(self.formatBytes(result.reclaimedBytes))"
            self.scan()
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
}

struct ContentView: View {
    @StateObject private var vm = CleanerViewModel()
    @State private var hoveredBarSummary: TargetSummary?

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [Color(nsColor: .windowBackgroundColor), Color(nsColor: .underPageBackgroundColor)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    headerCard
                    targetCard
                    resultsCard
                }
                .padding(.top, 16)
                .padding(.horizontal, 16)
                .padding(.bottom, 88)
            }

            floatingActionButton
        }
        .frame(minWidth: 920, minHeight: 760)
        .alert("Clean selected cache paths?", isPresented: $vm.showConfirmAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clean", role: .destructive) { vm.clean() }
        } message: {
            Text("This will remove \(vm.selectedEntriesForCleaning.count) selected path(s), up to \(vm.formatBytes(vm.selectedCleanBytes)).")
        }
        .onAppear {
            vm.scan()
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cache Storage")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("Analyze and clean heavy app and development caches")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    if vm.totalBytes > 0 {
                        Text(vm.formatBytes(vm.totalBytes))
                            .font(.system(size: 26, weight: .semibold, design: .rounded))
                        Text("Reclaimable")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(spacing: 10) {
                if vm.savedNowBytes > 0 {
                    statPill(title: "Saved now", value: vm.formatBytes(vm.savedNowBytes), color: .green)
                }
                if vm.allTimeSavedBytes > 0 {
                    statPill(title: "All-time saved", value: vm.formatBytes(vm.allTimeSavedBytes), color: .mint)
                }
                Spacer()
            }

            storageBar

            Text(vm.status)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private var storageBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { proxy in
                let width = max(proxy.size.width, 1)
                let total = max(vm.totalBytes, 1)

                HStack(spacing: 1) {
                    ForEach(vm.targetSummaries) { summary in
                        let fraction = Double(summary.size) / Double(total)
                        Rectangle()
                            .fill(vm.style(for: summary.id).color.gradient)
                            .frame(width: max(6, width * fraction))
                            .contentShape(Rectangle())
                            .onHover { hovering in
                                if hovering {
                                    hoveredBarSummary = summary
                                } else if hoveredBarSummary?.id == summary.id {
                                    hoveredBarSummary = nil
                                }
                            }
                            .help("\(summary.target.name)\n\(vm.formatBytes(summary.size))")
                    }

                    if vm.targetSummaries.isEmpty {
                        Rectangle()
                            .fill(Color.gray.opacity(0.25))
                            .help("No scanned cache data")
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .frame(height: 20)

            if let hovered = hoveredBarSummary {
                HStack(spacing: 8) {
                    Circle()
                        .fill(vm.style(for: hovered.id).color)
                        .frame(width: 8, height: 8)
                    Text(hovered.target.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(vm.formatBytes(hovered.size))
                        .font(.caption.monospacedDigit())
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.08), in: Capsule(style: .continuous))
                .transition(.opacity)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(vm.targetSummaries) { summary in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(vm.style(for: summary.id).color)
                                .frame(width: 8, height: 8)
                            Text(summary.target.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(vm.formatBytes(summary.size))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var targetCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Cleanup Targets")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Select All") { vm.selectAll() }
                Button("Deselect All") { vm.clearSelection() }
            }

            ForEach(allTargets) { target in
                let style = vm.style(for: target.id)
                HStack(spacing: 12) {
                    Image(systemName: style.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(style.color)
                        .frame(width: 28, height: 28)
                        .background(style.color.opacity(0.18), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(target.name)
                            .font(.body.weight(.medium))
                        Text(target.details)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if vm.isScanning {
                        SkeletonBlock(width: 72, height: 16, cornerRadius: 6)
                            .frame(minWidth: 90, alignment: .trailing)
                    } else {
                        if vm.targetSize(for: target.id) > 0 {
                            Text(vm.formatBytes(vm.targetSize(for: target.id)))
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 90, alignment: .trailing)
                        }
                    }
                    Toggle("", isOn: Binding(
                        get: { vm.selectedTargetIDs.contains(target.id) },
                        set: { isOn in vm.setTargetSelection(targetID: target.id, isOn: isOn) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                }
                .padding(.vertical, 6)

                if target.id != allTargets.last?.id {
                    Divider().opacity(0.45)
                }
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private var resultsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Detected Cache Paths")
                    .font(.title3.weight(.semibold))
                Spacer()
                Text("\(vm.scopedEntries.count) item(s)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if vm.isScanning {
                skeletonResults
            } else if vm.scopedEntries.isEmpty {
                Text("No cache paths found for selected targets.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
            } else {
                LazyVStack(spacing: 6) {
                    ForEach(vm.scopedEntries) { entry in
                        let style = vm.style(for: entry.targetID)
                        HStack(spacing: 10) {
                            Toggle("", isOn: Binding(
                                get: { vm.isEntrySelected(entry) },
                                set: { isOn in vm.setEntrySelection(entry: entry, isOn: isOn) }
                            ))
                            .toggleStyle(.checkbox)

                            Circle()
                                .fill(style.color)
                                .frame(width: 8, height: 8)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.path)
                                    .font(.caption.monospaced())
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Text(entry.targetID)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(vm.formatBytes(entry.size))
                                .font(.callout.monospacedDigit())
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private var skeletonResults: some View {
        LazyVStack(spacing: 8) {
            ForEach(0..<6, id: \.self) { _ in
                HStack(spacing: 10) {
                    SkeletonBlock(width: 14, height: 14, cornerRadius: 7)
                    VStack(alignment: .leading, spacing: 6) {
                        SkeletonBlock(width: 420, height: 12, cornerRadius: 6)
                        SkeletonBlock(width: 120, height: 10, cornerRadius: 5)
                    }
                    Spacer()
                    SkeletonBlock(width: 74, height: 14, cornerRadius: 6)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private var floatingActionButton: some View {
        let isActionClean = vm.hasScanned && vm.canClean && !vm.isScanning
        let isBusy = vm.isScanning || vm.isCleaning
        let actionTitle = vm.isScanning ? "Scanning" : (vm.isCleaning ? "Deleting" : (isActionClean ? "Delete" : "Scan"))
        let actionIcon = (vm.isCleaning || isActionClean) ? "trash.fill" : "magnifyingglass"
        let actionColor = (vm.isCleaning || isActionClean) ? Color.red : Color.accentColor

        return Button {
            if isBusy { return }
            if isActionClean {
                vm.requestClean()
            } else {
                vm.scan()
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: actionIcon)
                    .font(.system(size: 22, weight: .bold))
                Text(actionTitle)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(width: 112, height: 112)
            .background(
                Circle()
                    .fill(actionColor.gradient)
            )
        }
        .buttonStyle(.plain)
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
        )
        .overlay {
            if vm.isScanning || vm.isCleaning {
                ActionArcRing(color: vm.isCleaning ? .red : .accentColor)
            }
        }
        .shadow(color: actionColor.opacity(0.35), radius: 12, x: 0, y: 8)
        .disabled((!vm.canScan && !isActionClean) || isBusy)
        .padding(.bottom, 10)
    }

    private func statPill(title: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.06), in: Capsule(style: .continuous))
    }
}

struct ActionArcRing: View {
    let color: Color
    @State private var spinning = false

    var body: some View {
        Circle()
            .trim(from: 0.08, to: 0.34)
            .stroke(
                AngularGradient(colors: [color.opacity(0.2), color.opacity(0.95), color.opacity(0.2)], center: .center),
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
            )
            .rotationEffect(.degrees(spinning ? 450 : 90))
            .animation(.linear(duration: 1.05).repeatForever(autoreverses: false), value: spinning)
            .onAppear { spinning = true }
            .onDisappear { spinning = false }
            .frame(width: 126, height: 126)
    }
}

struct SkeletonBlock: View {
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat

    @State private var shimmerOffset: CGFloat = -180

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.white.opacity(0.14))
            .frame(width: width, height: height)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.0), Color.white.opacity(0.32), Color.white.opacity(0.0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: shimmerOffset)
            }
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.05).repeatForever(autoreverses: false)) {
                    shimmerOffset = 180
                }
            }
    }
}

let allTargets: [CacheTarget] = [
    CacheTarget(
        id: "xcode",
        name: "Xcode build cache",
        details: "DerivedData, module caches, and Xcode temp caches",
        patterns: [
            "~/Library/Developer/Xcode/DerivedData",
            "~/Library/Developer/Xcode/ModuleCache.noindex",
            "~/Library/Caches/com.apple.dt.Xcode"
        ]
    ),
    CacheTarget(
        id: "ios-simulator",
        name: "iOS Simulator cache",
        details: "CoreSimulator caches and per-device runtime caches",
        patterns: [
            "~/Library/Developer/CoreSimulator/Caches",
            "~/Library/Developer/CoreSimulator/Devices/*/data/Library/Caches"
        ]
    ),
    CacheTarget(
        id: "node",
        name: "Node.js package managers",
        details: "npm, Yarn, pnpm, and bun caches",
        patterns: [
            "~/.npm/_cacache",
            "~/Library/Caches/npm",
            "~/.cache/npm",
            "~/Library/Caches/Yarn",
            "~/.cache/yarn",
            "~/.pnpm-store",
            "~/.yarn/berry/cache",
            "~/.bun/install/cache"
        ]
    ),
    CacheTarget(
        id: "python",
        name: "Python tooling",
        details: "pip, Poetry, PDM, and uv caches",
        patterns: [
            "~/Library/Caches/pip",
            "~/.cache/pip",
            "~/.cache/pypoetry",
            "~/.cache/pdm",
            "~/.cache/uv"
        ]
    ),
    CacheTarget(
        id: "android-studio",
        name: "Android Studio",
        details: "Android Studio system and cache directories",
        patterns: [
            "~/Library/Caches/Google/AndroidStudio*",
            "~/Library/Logs/Google/AndroidStudio*",
            "~/Library/Application Support/Google/AndroidStudio*/caches",
            "~/Library/Application Support/Google/AndroidStudio*/system"
        ]
    ),
    CacheTarget(
        id: "build-tools",
        name: "General build tools",
        details: "CocoaPods, Carthage, and Homebrew download caches",
        patterns: [
            "~/Library/Caches/CocoaPods",
            "~/Library/Caches/org.carthage.CarthageKit",
            "~/Library/Caches/Homebrew"
        ]
    ),
    CacheTarget(
        id: "docker",
        name: "Docker caches",
        details: "Docker Desktop caches, logs, and temporary build data",
        patterns: [
            "~/Library/Caches/com.docker.docker",
            "~/Library/Containers/com.docker.docker/Data/log",
            "~/Library/Containers/com.docker.docker/Data/cache",
            "~/Library/Group Containers/group.com.docker/cache"
        ]
    ),
    CacheTarget(
        id: "java-kotlin",
        name: "Java/Kotlin build caches",
        details: "Gradle, Maven, Ivy, and Coursier downloaded artifacts",
        patterns: [
            "~/.gradle/caches",
            "~/.gradle/wrapper/dists",
            "~/Library/Caches/gradle",
            "~/.m2/repository",
            "~/.ivy2/cache",
            "~/Library/Caches/Coursier"
        ]
    ),
    CacheTarget(
        id: "go-rust",
        name: "Go and Rust caches",
        details: "Go build/module cache and Cargo registry/git caches",
        patterns: [
            "~/.cache/go-build",
            "~/Library/Caches/go-build",
            "~/go/pkg/mod/cache",
            "~/.cargo/registry/cache",
            "~/.cargo/git/db"
        ]
    ),
    CacheTarget(
        id: "dotnet",
        name: ".NET / NuGet",
        details: "NuGet package and temporary cache folders",
        patterns: [
            "~/.nuget/packages",
            "~/Library/Caches/NuGet",
            "~/Library/Caches/NuGetScratch"
        ]
    ),
    CacheTarget(
        id: "editors",
        name: "Editors and IDEs",
        details: "VS Code, Cursor, and JetBrains cache folders",
        patterns: [
            "~/Library/Application Support/Code/Cache",
            "~/Library/Application Support/Code/CachedData",
            "~/Library/Application Support/Code/Service Worker/CacheStorage",
            "~/Library/Application Support/Cursor/Cache",
            "~/Library/Application Support/Cursor/CachedData",
            "~/Library/Caches/JetBrains",
            "~/Library/Logs/JetBrains",
            "~/Library/Application Support/JetBrains/*/caches"
        ]
    ),
    CacheTarget(
        id: "design-tools",
        name: "Design tools",
        details: "Figma and Adobe media/cache files",
        patterns: [
            "~/Library/Caches/Figma",
            "~/Library/Application Support/Figma/Cache",
            "~/Library/Application Support/Figma/Code Cache",
            "~/Library/Application Support/Figma/GPUCache",
            "~/Library/Application Support/Figma/Service Worker/CacheStorage",
            "~/Library/Caches/Adobe",
            "~/Library/Application Support/Adobe/Common/Media Cache",
            "~/Library/Application Support/Adobe/Common/Media Cache Files"
        ]
    ),
    CacheTarget(
        id: "unity",
        name: "Unity",
        details: "Unity editor caches and package cache folders",
        patterns: [
            "~/Library/Unity/cache",
            "~/Library/Caches/com.unity3d.UnityEditor",
            "~/Library/Application Support/Unity/Asset Store-5.x"
        ]
    ),
    CacheTarget(
        id: "browsers",
        name: "Browser caches",
        details: "Chrome and Firefox cache paths used by local web/dev workflows",
        patterns: [
            "~/Library/Caches/Google/Chrome",
            "~/Library/Application Support/Google/Chrome/Default/Code Cache",
            "~/Library/Application Support/Google/Chrome/Default/Service Worker/CacheStorage",
            "~/Library/Caches/Firefox",
            "~/Library/Caches/Mozilla"
        ]
    )
]

@main
struct CachifyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}
