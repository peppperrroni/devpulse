public enum ProtectedPaths {
    public static let relativeRoots = [
        "", "Library", "Documents", "Desktop", "Downloads", "Pictures", "Movies", "Music",
        "Applications", "Library/Containers", "Library/Group Containers", "Library/Mobile Documents",
    ]

    public static func roots(home: String) -> [String] {
        relativeRoots.map { $0.isEmpty ? home : home + "/" + $0 }
    }

    public static func isProtected(_ path: String, home: String) -> Bool {
        roots(home: home).contains(path)
    }

    /// True for a protected root or any directory that contains one (e.g. `/Users`).
    public static func isProtectedOrAncestor(_ path: String, home: String) -> Bool {
        roots(home: home).contains { $0 == path || $0.hasPrefix(path + "/") }
    }
}
