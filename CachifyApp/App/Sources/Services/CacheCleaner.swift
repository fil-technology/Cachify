import Foundation

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
