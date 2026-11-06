import Foundation

/// Space Lens: a single breadth-first walk that accumulates sizes for every
/// visible level of the tree at once. Nodes are built from one enumeration only,
/// so scanning is O(entries) instead of re-walking each directory.
enum SpaceLensEngine {
    private static let fm = FileManager.default
    /// Lean key set: dates / logical size details are not needed for the lens, and
    /// asking for fewer prefetched keys measurably shortens large enumerations.
    private static let resourceKeys: Set<URLResourceKey> = [
        .isRegularFileKey,
        .isDirectoryKey,
        .isSymbolicLinkKey,
        .totalFileAllocatedSizeKey,
        .fileAllocatedSizeKey,
        .totalFileSizeKey
    ]

    /// A tree node under construction. Filled during the single traversal.
    private struct NodeBox {
        let name: String
        var byteCount: Int64
        var isDirectory: Bool
        var childCount: Int
    }

    private static let emptyStatusInterval = 512

    static func scan(root: URL,
                     maxDepth: Int,
                     progress: @escaping @Sendable (Double, String) -> Void) async -> SpaceNode {
        let depth = min(3, max(1, maxDepth))
        let rootURL = ToolsSupport.standardizedURL(root)
        let rootName = rootURL.lastPathComponent.isEmpty ? rootURL.path : rootURL.lastPathComponent
        progress(0.01, L("正在分析 \(rootName)…"))

        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: rootURL.path, isDirectory: &isDirectory) else {
            progress(1, L("目录不存在：\(rootName)"))
            return SpaceNode(name: rootName, url: rootURL, byteCount: 0,
                             isDirectory: true, childCount: 0, children: [])
        }

        if !isDirectory.boolValue {
            let size = FileMeasure.allocatedSize(ofItemAt: rootURL)
            progress(1, L("分析完成"))
            return SpaceNode(name: rootName, url: rootURL, byteCount: size,
                             isDirectory: false, childCount: 0, children: [])
        }

        let rootPath = rootURL.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"

        var boxes: [String: NodeBox] = [:]
        var rootSize: Int64 = 0
        var rootChildDirectoryCount = 0
        var visited = 0
        var cancelled = false

        guard let enumerator = fm.enumerator(at: rootURL,
                                             includingPropertiesForKeys: Array(resourceKeys),
                                             options: [],
                                             errorHandler: { _, _ in true }) else {
            progress(1, L("无法读取目录：\(rootName)"))
            return SpaceNode(name: rootName, url: rootURL, byteCount: 0,
                             isDirectory: true, childCount: 0, children: [])
        }

        while let url = enumerator.nextObject() as? URL {
            visited += 1
            if visited % emptyStatusInterval == 0 {
                if Task.isCancelled {
                    cancelled = true
                    break
                }
                let fraction = 0.03 + 0.90 * Double(visited) / Double(visited + 25_000)
                progress(min(0.95, fraction), L("正在分析…已检查 \(visited) 项"))
            }

            guard let values = try? url.resourceValues(forKeys: resourceKeys) else { continue }
            if values.isSymbolicLink == true {
                if values.isDirectory == true {
                    enumerator.skipDescendants()
                }
                continue
            }

            let relative: String
            if url.path.hasPrefix(prefix) {
                relative = String(url.path.dropFirst(prefix.count))
            } else {
                relative = url.lastPathComponent
            }
            let components = relative.split(separator: "/", maxSplits: depth + 1,
                                            omittingEmptySubsequences: true)
            guard !components.isEmpty else { continue }

            if values.isDirectory == true {
                // Register directories that will appear in the result tree.
                if components.count <= depth {
                    let nodePath = prefix + components.joined(separator: "/")
                    let name = String(components[components.count - 1])
                    var box = boxes[nodePath] ?? NodeBox(name: name, byteCount: 0,
                                                         isDirectory: true, childCount: 0)
                    box.isDirectory = true
                    boxes[nodePath] = box
                    incrementParentChildCount(components: components, prefix: prefix,
                                              rootChildDirectoryCount: &rootChildDirectoryCount,
                                              boxes: &boxes)
                } else if components.count == depth + 1 {
                    // Count direct subdirectories of nodes at the deepest visible level.
                    let parentPath = prefix + components.prefix(depth).joined(separator: "/")
                    if var parent = boxes[parentPath] {
                        parent.childCount += 1
                        boxes[parentPath] = parent
                    }
                }
                continue
            }

            guard values.isRegularFile == true else { continue }
            let byteCount = FileMeasure.byteCount(from: values)
            guard byteCount > 0 else { continue }
            rootSize += byteCount

            let levels = min(components.count, depth)
            if levels > 0 {
                for level in 1...levels {
                    let nodePath = prefix + components.prefix(level).joined(separator: "/")
                    let isLeaf = level == components.count
                    let name = String(components[level - 1])
                    var box = boxes[nodePath] ?? NodeBox(name: name, byteCount: 0,
                                                         isDirectory: !isLeaf, childCount: 0)
                    if isLeaf { box.isDirectory = false }
                    box.byteCount += byteCount
                    boxes[nodePath] = box
                }
            }
        }

        // Link nodes into a tree. Every visible node's parent is also visible
        // (depth <= maxDepth), so parent lookup never fails in practice.
        var childPaths: [String: [String]] = [:]
        var rootChildPaths: [String] = []
        for path in boxes.keys {
            let parentPath = (path as NSString).deletingLastPathComponent
            if parentPath == rootPath {
                rootChildPaths.append(path)
            } else {
                childPaths[parentPath, default: []].append(path)
            }
        }

        func buildNode(_ path: String) -> SpaceNode {
            guard let box = boxes[path] else {
                return SpaceNode(name: (path as NSString).lastPathComponent,
                                 url: URL(fileURLWithPath: path),
                                 byteCount: 0, isDirectory: true,
                                 childCount: 0, children: [])
            }
            var children: [SpaceNode] = []
            if box.isDirectory {
                children = (childPaths[path] ?? []).map(buildNode)
                    .sorted { $0.byteCount > $1.byteCount }
            }
            return SpaceNode(name: box.name,
                             url: URL(fileURLWithPath: path),
                             byteCount: box.byteCount,
                             isDirectory: box.isDirectory,
                             childCount: box.childCount,
                             children: children)
        }

        let children = rootChildPaths.map(buildNode).sorted { $0.byteCount > $1.byteCount }
        let rootNode = SpaceNode(name: rootName,
                                 url: rootURL,
                                 byteCount: rootSize,
                                 isDirectory: true,
                                 childCount: rootChildDirectoryCount,
                                 children: children)

        if cancelled {
            progress(1, L("分析已取消，显示部分结果"))
        } else {
            progress(1, L("分析完成，共 \(Format.bytes(rootSize))"))
        }
        return rootNode
    }

    private static func incrementParentChildCount(components: [Substring],
                                                  prefix: String,
                                                  rootChildDirectoryCount: inout Int,
                                                  boxes: inout [String: NodeBox]) {
        if components.count == 1 {
            rootChildDirectoryCount += 1
        } else {
            let parentPath = prefix + components.prefix(components.count - 1).joined(separator: "/")
            if var parent = boxes[parentPath] {
                parent.childCount += 1
                boxes[parentPath] = parent
            }
        }
    }
}
