import Foundation

public struct TopItem: Identifiable, Hashable, Sendable {
    public var path: String
    public var size: Int64
    public var kind: NodeKind
    public var modified: Date?

    public var id: String { path }

    init(_ node: ScanNode) {
        path = node.path
        size = node.size
        kind = node.kind
        modified = node.modified
    }
}

public enum TopItems {
    public static func files(in root: ScanNode, limit: Int) -> [TopItem] {
        flatten(root).filter { $0.kind != .folder }
            .sorted { $0.size > $1.size }
            .prefix(limit).map(TopItem.init)
    }

    /// Folders where the weight actually sits: no child folder holds >= 50 % of the
    /// size, not a protected root, and no overlap with a larger chosen folder.
    public static func folders(in root: ScanNode, home: String, limit: Int) -> [TopItem] {
        let candidates = flatten(root)
            .filter { $0.kind == .folder && $0.size > 0 && $0.largestChildFolder * 2 < $0.size }
            .filter { !ProtectedPaths.isProtected($0.path, home: home) }
            .sorted { $0.size > $1.size }
        var chosen: [ScanNode] = []
        for node in candidates where chosen.count < limit {
            let overlaps = chosen.contains { $0.path.hasPrefix(node.path + "/") || node.path.hasPrefix($0.path + "/") }
            if !overlaps { chosen.append(node) }
        }
        return chosen.map(TopItem.init)
    }

    public static func all(in root: ScanNode, home: String, limit: Int) -> [TopItem] {
        (folders(in: root, home: home, limit: limit) + files(in: root, limit: limit))
            .sorted { $0.size > $1.size }
            .prefix(limit).map { $0 }
    }

    private static func flatten(_ node: ScanNode) -> [ScanNode] {
        [node] + node.children.flatMap(flatten)
    }
}
