import Foundation

public enum DeleteRefusal: Error, Equatable, Sendable {
    case outsideHome, protected, missing
}

public struct DeletionReport: Sendable, Equatable {
    public struct Failure: Sendable, Equatable {
        public var path: String
        public var reason: String
    }

    public var freed: Int64 = 0
    public var deleted: [String] = []
    public var failures: [Failure] = []
}

/// Permanent deletion guarded by a path check that runs right before removal.
public struct Deleter: Sendable {
    public let home: String

    public init(home: String = NSHomeDirectory()) {
        self.home = Self.resolve(home)
    }

    /// Returns the resolved path that is safe to remove.
    public func validate(_ path: String) throws(DeleteRefusal) -> String {
        // A relative path would resolve against the process cwd, not home.
        guard path.hasPrefix("/") else { throw .outsideHome }
        let resolved = Self.resolve(path)
        guard resolved.hasPrefix(home + "/") else { throw .outsideHome }
        guard !ProtectedPaths.isProtectedOrAncestor(resolved, home: home) else { throw .protected }
        guard FileManager.default.fileExists(atPath: resolved) else { throw .missing }
        return resolved
    }

    public func delete(_ items: [TopItem]) -> DeletionReport {
        var report = DeletionReport()
        for item in items {
            do {
                let path = try validate(item.path)
                try FileManager.default.removeItem(atPath: path)
                report.freed += item.size
                report.deleted.append(item.path)
            } catch let refusal as DeleteRefusal {
                report.failures.append(.init(path: item.path, reason: Self.describe(refusal)))
            } catch {
                report.failures.append(.init(path: item.path, reason: error.localizedDescription))
            }
        }
        return report
    }

    static func resolve(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path
    }

    static func describe(_ refusal: DeleteRefusal) -> String {
        switch refusal {
        case .outsideHome: "вне домашней папки"
        case .protected: "защищённая папка"
        case .missing: "уже не существует"
        }
    }
}
