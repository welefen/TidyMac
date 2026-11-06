import Foundation

enum SpaceLensEngine {
    static func scan(root: URL,
                     maxDepth: Int,
                     progress: @escaping @Sendable (Double, String) -> Void) async -> SpaceNode {
        progress(1, "分析完成")
        return SpaceNode(name: root.lastPathComponent, url: root, byteCount: 0,
                         isDirectory: true, childCount: 0, children: [])
    }
}
