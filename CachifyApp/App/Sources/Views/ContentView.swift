import SwiftUI

struct ContentView: View {
    private struct BarSlice: Identifiable {
        let id: String
        let summary: TargetSummary
        let startX: CGFloat
        let width: CGFloat

        var midX: CGFloat {
            startX + (width / 2)
        }
    }

    private struct HoveredBarInfo {
        let id: String
        let summary: TargetSummary
        let midX: CGFloat
    }

    @StateObject private var vm = CleanerViewModel()
    @State private var hoveredBarInfo: HoveredBarInfo?
    @State private var hoveredTargetID: String?
    @State private var inspectorTargetID: String?
    @State private var inspectorSelectedEntryIDs: Set<UUID> = []

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
            vm.handleOnAppear()
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.windows.first?.makeKeyAndOrderFront(nil)
            }
        }
        .onReceive(vm.$scanEntries) { _ in
            syncInspectorSelection()
        }
        .sheet(isPresented: Binding(
            get: { inspectorTargetID != nil },
            set: { show in
                if !show {
                    inspectorTargetID = nil
                    inspectorSelectedEntryIDs.removeAll()
                }
            }
        )) {
            if let targetID = inspectorTargetID, let target = vm.target(for: targetID) {
                TargetInspectorSheet(
                    target: target,
                    entries: vm.entries(for: targetID),
                    isCleaning: vm.isCleaning,
                    formatBytes: vm.formatBytes,
                    onDeleteSelected: { entries in
                        vm.clean(entries: entries)
                        inspectorSelectedEntryIDs.subtract(entries.map { $0.id })
                    },
                    onDeleteSingle: { entry in
                        vm.clean(entries: [entry])
                        inspectorSelectedEntryIDs.remove(entry.id)
                    },
                    onClose: {
                        inspectorTargetID = nil
                        inspectorSelectedEntryIDs.removeAll()
                    },
                    selectedEntryIDs: $inspectorSelectedEntryIDs
                )
            } else {
                Text("No target selected.")
                    .frame(minWidth: 480, minHeight: 300)
            }
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
                    if vm.displayedTotalBytes > 0 {
                        Text(vm.formatBytes(vm.displayedTotalBytes))
                            .font(.system(size: 26, weight: .semibold, design: .rounded))
                        Text(vm.isShowingSnapshotData ? "Last scan snapshot" : "Reclaimable")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(spacing: 10) {
                if vm.savedNowBytes > 0 {
                    statPill(
                        title: vm.hasCleanedInSession ? "Saved now" : "Saved last time",
                        value: vm.formatBytes(vm.savedNowBytes),
                        color: .green
                    )
                }
                if vm.allTimeSavedBytes > 0 {
                    statPill(title: "All-time saved", value: vm.formatBytes(vm.allTimeSavedBytes), color: .mint)
                }
                if !vm.hasFolderAccess {
                    Button("Grant Home Access") {
                        vm.requestFolderAccess()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
                Spacer()
            }

            storageBar

            Text(vm.status)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if !vm.diagnostics.isEmpty {
                diagnosticsView
            }
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
                let summaries = vm.displayedTargetSummaries
                let total = max(summaries.reduce(0) { $0 + $1.size }, 1)
                let slices = storageSlices(for: summaries, width: width, total: total)

                ZStack(alignment: .topLeading) {
                    HStack(spacing: 1) {
                        ForEach(slices) { slice in
                            Rectangle()
                                .fill(vm.style(for: slice.summary.id).color.gradient)
                                .frame(width: slice.width)
                                .contentShape(Rectangle())
                                .onHover { hovering in
                                    if hovering {
                                        hoveredBarInfo = HoveredBarInfo(
                                            id: slice.id,
                                            summary: slice.summary,
                                            midX: slice.midX
                                        )
                                    } else if hoveredBarInfo?.id == slice.id {
                                        hoveredBarInfo = nil
                                    }
                                }
                                .help("\(slice.summary.target.name)\n\(vm.formatBytes(slice.summary.size))")
                        }

                        if summaries.isEmpty {
                            Rectangle()
                                .fill(Color.gray.opacity(0.25))
                                .help("No scanned cache data")
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                    if let hovered = hoveredBarInfo {
                        tooltipView(summary: hovered.summary)
                            .position(
                                x: max(100, min(width - 100, hovered.midX)),
                                y: -16
                            )
                            .allowsHitTesting(false)
                    }
                }
            }
            .frame(height: 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(vm.displayedTargetSummaries) { summary in
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
        TargetCleanupCard(
            targets: vm.sortedTargets,
            selectedTargetIDs: vm.selectedTargetIDs,
            hoveredTargetID: hoveredTargetID,
            isScanning: vm.isScanning,
            formatBytes: vm.formatBytes,
            targetSize: vm.targetSize,
            styleFor: vm.style,
            onSelectAll: vm.selectAll,
            onDeselectAll: vm.clearSelection,
            onHover: { targetID in
                hoveredTargetID = targetID
            },
            onOpenTarget: { targetID in
                inspectorTargetID = targetID
                inspectorSelectedEntryIDs = Set(vm.entries(for: targetID).map(\.id))
            },
            onTargetSelectionChanged: vm.setTargetSelection
        )
    }

    private var floatingActionButton: some View {
        let needsAccess = !vm.hasFolderAccess
        let isActionClean = vm.hasScanned && vm.canClean && !vm.isScanning
        let isBusy = vm.isScanning || vm.isCleaning
        let actionTitle = needsAccess ? "Grant Access" : (vm.isScanning ? "Scanning" : (vm.isCleaning ? "Deleting" : (isActionClean ? "Delete" : "Scan")))
        let actionIcon = needsAccess ? "folder.badge.plus" : ((vm.isCleaning || isActionClean) ? "trash.fill" : "magnifyingglass")
        let actionColor = needsAccess ? Color.orange : ((vm.isCleaning || isActionClean) ? Color.red : Color.accentColor)

        return Button {
            if isBusy { return }
            if needsAccess {
                vm.requestFolderAccess()
            } else if isActionClean {
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
            if !needsAccess && (vm.isScanning || vm.isCleaning) {
                ActionArcRing(color: vm.isCleaning ? .red : .accentColor)
            }
        }
        .shadow(color: actionColor.opacity(0.35), radius: 12, x: 0, y: 8)
        .disabled((!needsAccess && !vm.canScan && !isActionClean) || isBusy)
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

    private var diagnosticsView: some View {
        DisclosureGroup("Diagnostics") {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(vm.diagnostics.suffix(10).enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.top, 4)
        }
        .font(.footnote)
        .tint(.secondary)
    }

    private func syncInspectorSelection() {
        guard let targetID = inspectorTargetID else { return }
        let validIDs = Set(vm.entries(for: targetID).map(\.id))
        inspectorSelectedEntryIDs = inspectorSelectedEntryIDs.intersection(validIDs)
    }

    private func storageSlices(for summaries: [TargetSummary], width: CGFloat, total: Int64) -> [BarSlice] {
        var cursor: CGFloat = 0
        var slices: [BarSlice] = []

        for summary in summaries {
            let fraction = Double(summary.size) / Double(total)
            let sliceWidth = max(6, width * fraction)
            slices.append(
                BarSlice(
                    id: summary.id,
                    summary: summary,
                    startX: cursor,
                    width: sliceWidth
                )
            )
            cursor += sliceWidth + 1
        }

        return slices
    }

    private func tooltipView(summary: TargetSummary) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(vm.style(for: summary.id).color)
                .frame(width: 8, height: 8)
            Text(summary.target.name)
                .font(.caption)
            Text(vm.formatBytes(summary.size))
                .font(.caption.monospacedDigit())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 8, x: 0, y: 4)
    }
}
