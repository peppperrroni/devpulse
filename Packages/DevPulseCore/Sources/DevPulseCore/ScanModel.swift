import Foundation

public enum NodeKind: String, Codable, Sendable {
    case file, folder, package
}

public struct ScanNode: Codable, Sendable, Equatable {
    public var path: String
    public var size: Int64
    public var kind: NodeKind
    public var modified: Date?
    /// Size of the largest direct child folder, measured before small nodes were pruned.
    public var largestChildFolder: Int64
    public var children: [ScanNode]

    public init(path: String, size: Int64, kind: NodeKind, modified: Date?, largestChildFolder: Int64, children: [ScanNode]) {
        self.path = path
        self.size = size
        self.kind = kind
        self.modified = modified
        self.largestChildFolder = largestChildFolder
        self.children = children
    }
}

public struct ScanResult: Codable, Sendable, Equatable {
    public static let schemaVersion = 1
    public var version: Int
    public var date: Date
    public var root: ScanNode
    public var skipped: [String]

    public init(date: Date, root: ScanNode, skipped: [String]) {
        self.version = Self.schemaVersion
        self.date = date
        self.root = root
        self.skipped = skipped
    }
}

public struct ScanProgress: Sendable, Equatable {
    public var bytes: Int64
    public var items: Int

    public init(bytes: Int64, items: Int) {
        self.bytes = bytes
        self.items = items
    }
}
