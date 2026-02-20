import SwiftUI

struct TargetCleanupCard: View {
    let targets: [CacheTarget]
    let selectedTargetIDs: Set<String>
    let hoveredTargetID: String?
    let isScanning: Bool
    let formatBytes: (Int64) -> String
    let targetSize: (String) -> Int64
    let styleFor: (String) -> TargetStyle
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void
    let onHover: (String?) -> Void
    let onOpenTarget: (String) -> Void
    let onTargetSelectionChanged: (String, Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Cleanup Targets")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Select All", action: onSelectAll)
                Button("Deselect All", action: onDeselectAll)
            }

            ForEach(Array(targets.enumerated()), id: \.element.id) { index, target in
                let style = styleFor(target.id)
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
                    if isScanning {
                        SkeletonBlock(width: 72, height: 16, cornerRadius: 6)
                            .frame(minWidth: 90, alignment: .trailing)
                    } else if targetSize(target.id) > 0 {
                        Text(formatBytes(targetSize(target.id)))
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 90, alignment: .trailing)
                    }

                    Toggle("", isOn: Binding(
                        get: { selectedTargetIDs.contains(target.id) },
                        set: { isOn in onTargetSelectionChanged(target.id, isOn) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(hoveredTargetID == target.id ? Color.white.opacity(0.08) : Color.clear)
                )
                .onHover { hovering in
                    onHover(hovering ? target.id : nil)
                }
                .onTapGesture {
                    onOpenTarget(target.id)
                }

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
}
