import Foundation

public struct ScanCache: Sendable {
    public let url: URL

    public static var defaultURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appending(path: "DevPulse/scan.json")
    }

    public init(url: URL) {
        self.url = url
    }

    /// nil when missing; a corrupt or outdated file is deleted so the caller rescans.
    public func load() -> ScanResult? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let result = try? JSONDecoder().decode(ScanResult.self, from: data),
              result.version == ScanResult.schemaVersion else {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        return result
    }

    public func save(_ result: ScanResult) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(result).write(to: url, options: .atomic)
    }
}

extension ScanResult {
    /// Removes the node at `path` and subtracts its size from every ancestor.
    public mutating func applyDeletion(of path: String) {
        _ = Self.remove(path, from: &root)
    }

    private static func remove(_ path: String, from node: inout ScanNode) -> Int64? {
        if let i = node.children.firstIndex(where: { $0.path == path }) {
            let removed = node.children.remove(at: i).size
            node.size -= removed
            node.largestChildFolder = largestFolder(in: node)
            return removed
        }
        guard let i = node.children.firstIndex(where: { path.hasPrefix($0.path + "/") }),
              let removed = remove(path, from: &node.children[i]) else { return nil }
        node.size -= removed
        node.largestChildFolder = largestFolder(in: node)
        node.children.sort { $0.size > $1.size }
        return removed
    }

    /// Approximation after an edit: only kept (>= threshold) children are known.
    private static func largestFolder(in node: ScanNode) -> Int64 {
        node.children.filter { $0.kind == .folder }.map(\.size).max() ?? 0
    }
}
