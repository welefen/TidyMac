import Foundation

// MARK: - Exclusions

/// Normalized set of user-excluded paths with cheap containment checks.
///
/// The rule used by the scanner: a candidate is skipped when an excluded path is
/// an ancestor of it (or equal to it). While measuring a directory, excluded
/// subtrees are pruned so their bytes never count towards the total.
struct ScanExclusions: Sendable {
    private let roots: [String]

    init(_ raw: Set<String>) {
        self.init(Array(raw))
    }

    init(_ raw: [String]) {
        var seen = Set<String>()
        var result: [String] = []
        for item in raw {
            let normalized = SafetyPolicy.normalized(item)
            guard !normalized.isEmpty else { continue }
            if seen.insert(normalized).inserted {
                result.append(normalized)
            }
        }
        roots = result
    }

    var isEmpty: Bool { roots.isEmpty }

    var allPaths: [String] { roots }

    /// `url` is inside an excluded subtree (or exactly the excluded path).
    func covers(_ url: URL) -> Bool {
        covers(path: url.path)
    }

    func covers(path: String) -> Bool {
        guard !roots.isEmpty else { return false }
        let normalized = SafetyPolicy.normalized(path)
        for root in roots where SafetyPolicy.isDescendant(normalized, of: root) {
            return true
        }
        return false
    }

    /// Fast path used while enumerating large trees (paths are already absolute).
    func coversRaw(_ path: String) -> Bool {
        guard !roots.isEmpty else { return false }
        for root in roots where Self.isInside(path, root) {
            return true
        }
        return false
    }

    /// `url` contains an excluded path somewhere below it.
    func containsExcludedDescendant(_ url: URL) -> Bool {
        guard !roots.isEmpty else { return false }
        let normalized = SafetyPolicy.normalized(url.path)
        for root in roots where SafetyPolicy.isDescendant(root, of: normalized) {
            return true
        }
        return false
    }

    static func merged(_ other: [String]) -> ScanExclusions {
        ScanExclusions(other)
    }

    private static func isInside(_ path: String, _ root: String) -> Bool {
        if path == root { return true }
        if root == "/" { return path.hasPrefix("/") }
        return path.hasPrefix(root + "/")
    }
}

// MARK: - Measurement

/// Byte/file summary of a file or directory tree.
struct Footprint: Sendable {
    var bytes: Int64 = 0
    var fileCount: Int = 0
    var lastModified: Date?
}

/// Foundation-only measurement helpers that understand exclusions and cancellation.
enum ScanFileTool {
    static let keys: Set<URLResourceKey> = Set(FileMeasure.resourceKeys)

    /// Measures `url` without following symlinks and without counting excluded
    /// subtrees. Unreadable entries are skipped silently.
    static func footprint(of url: URL,
                          exclusions: ScanExclusions = ScanExclusions([]),
                          isCancelled: () -> Bool = { false }) -> Footprint {
        if isCancelled() { return Footprint() }
        if exclusions.covers(path: url.path) { return Footprint() }

        guard let values = try? url.resourceValues(forKeys: keys) else { return Footprint() }

        if values.isSymbolicLink == true {
            // Symlinks are never followed; removing the link itself frees no blocks.
            return Footprint(bytes: 0,
                             fileCount: 0,
                             lastModified: values.contentModificationDate)
        }

        if values.isRegularFile == true {
            return Footprint(bytes: FileMeasure.byteCount(from: values),
                             fileCount: 1,
                             lastModified: values.contentModificationDate)
        }

        var result = Footprint()
        guard values.isDirectory == true else {
            result.bytes = FileMeasure.byteCount(from: values)
            return result
        }

        let keyArray = Array(keys)
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: keyArray,
            options: [],
            errorHandler: { _, _ in true }
        ) else { return result }

        for case let child as URL in enumerator {
            if isCancelled() { break }
            let childPath = child.path
            if !exclusions.isEmpty, exclusions.coversRaw(childPath) {
                enumerator.skipDescendants()
                continue
            }
            guard let childValues = try? child.resourceValues(forKeys: keys) else { continue }
            if childValues.isSymbolicLink == true { continue }
            guard childValues.isRegularFile == true else { continue }
            result.bytes += FileMeasure.byteCount(from: childValues)
            result.fileCount += 1
            if let date = childValues.contentModificationDate {
                if result.lastModified == nil || date > result.lastModified! {
                    result.lastModified = date
                }
            }
        }
        return result
    }

    /// Top-level children of `directory` (hidden entries included) that are not
    /// covered by an exclusion.
    static func children(of directory: URL, exclusions: ScanExclusions = ScanExclusions([])) -> [URL] {
        HomePaths.children(of: directory).filter { !exclusions.covers($0) }
    }

    static func isDirectory(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values?.isSymbolicLink != true else { return false }
        return values?.isDirectory == true
    }

    static func isFile(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values?.isSymbolicLink != true else { return false }
        return values?.isRegularFile == true
    }

    static func name(of url: URL) -> String {
        let name = url.lastPathComponent
        return name.isEmpty ? url.path : name
    }
}

// MARK: - Aggregation

enum ScanAggregate {
    /// Keeps the `limit` largest items and folds the remainder into one synthetic item.
    static func compact(_ items: [ScanItem],
                        limit: Int,
                        aggregateID: String,
                        aggregateName: String,
                        aggregateKind: ItemKind,
                        aggregateSafety: SafetyLevel,
                        aggregateDetail: String) -> [ScanItem] {
        let sorted = items.sorted { $0.byteCount > $1.byteCount }
        guard sorted.count > limit, limit > 0 else { return sorted }
        let shown = Array(sorted.prefix(limit))
        let rest = Array(sorted.dropFirst(limit))
        guard !rest.isEmpty else { return shown }

        let urls = rest.flatMap(\.urls)
        let bytes = rest.reduce(Int64(0)) { $0 + $1.byteCount }
        let detail = aggregateDetail.replacingOccurrences(of: "{count}", with: "\(rest.count)")
        let modified = rest.compactMap(\.modifiedAt).max()
        let aggregate = ScanItem(id: aggregateID,
                                 name: aggregateName,
                                 urls: urls,
                                 byteCount: bytes,
                                 kind: aggregateKind,
                                 safety: aggregateSafety,
                                 detail: detail,
                                 modifiedAt: modified,
                                 isSelected: true)
        return shown + [aggregate]
    }
}
