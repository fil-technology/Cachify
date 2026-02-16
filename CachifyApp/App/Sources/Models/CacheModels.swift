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
