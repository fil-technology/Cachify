import SwiftUI

struct TargetInspectorSheet: View {
    let target: CacheTarget
    let entries: [ScanEntry]
    let isCleaning: Bool
    let formatBytes: (Int64) -> String
    let onDeleteSelected: ([ScanEntry]) -> Void
    let onDeleteSingle: (ScanEntry) -> Void
    let onClose: () -> Void

    @Binding var selectedEntryIDs: Set<UUID>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(target.name)
                        .font(.title2.weight(.semibold))
                    Text(target.details)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(formatBytes(entries.reduce(0) { $0 + $1.size }))
                    .font(.title3.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Button("Select All") {
                    selectedEntryIDs = Set(entries.map(\.id))
                }
                Button("Deselect All") {
                    selectedEntryIDs.removeAll()
                }
                Spacer()
                Button("Delete Selected") {
                    onDeleteSelected(entries.filter { selectedEntryIDs.contains($0.id) })
                    selectedEntryIDs = selectedEntryIDs.intersection(Set(entries.map(\.id)))
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(selectedEntryIDs.isEmpty || isCleaning)
                Button("Close", action: onClose)
            }

            if entries.isEmpty {
                Text("No cache items found for this target.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                List(entries) { entry in
                    HStack(spacing: 10) {
                        Button {
                            if selectedEntryIDs.contains(entry.id) {
                                selectedEntryIDs.remove(entry.id)
                            } else {
                                selectedEntryIDs.insert(entry.id)
                            }
                        } label: {
                            Image(systemName: selectedEntryIDs.contains(entry.id) ? "checkmark.square.fill" : "square")
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 2) {
                            Text((entry.path as NSString).lastPathComponent)
                                .font(.body.weight(.medium))
                                .lineLimit(1)
                            Text(entry.path)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        Text(formatBytes(entry.size))
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Button(role: .destructive) {
                            onDeleteSingle(entry)
                            selectedEntryIDs.remove(entry.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .disabled(isCleaning)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.inset)
            }
        }
        .padding(18)
        .frame(minWidth: 760, minHeight: 460)
    }
}
