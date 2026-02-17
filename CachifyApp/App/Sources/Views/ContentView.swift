import SwiftUI

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
            vm.handleOnAppear()
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

            let targets = vm.sortedTargets
            ForEach(Array(targets.enumerated()), id: \.element.id) { index, target in
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
                    } else if vm.targetSize(for: target.id) > 0 {
                        Text(vm.formatBytes(vm.targetSize(for: target.id)))
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 90, alignment: .trailing)
                    }

                    Toggle("", isOn: Binding(
                        get: { vm.selectedTargetIDs.contains(target.id) },
                        set: { isOn in vm.setTargetSelection(targetID: target.id, isOn: isOn) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                }
                .padding(.vertical, 6)

                if index < targets.count - 1 {
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
}
