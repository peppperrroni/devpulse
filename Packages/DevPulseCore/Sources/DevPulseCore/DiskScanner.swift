import Darwin
import Foundation

public struct DiskScanner: Sendable {
    public let keepThreshold: Int64

    public init(keepThreshold: Int64 = 50_000_000) {
        self.keepThreshold = keepThreshold
    }

    private static let keys: [URLResourceKey] = [
        .isDirectoryKey, .isPackageKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey,
        .fileAllocatedSizeKey, .contentModificationDateKey, .linkCountKey,
    ]

    private final class State {
        var bytes: Int64 = 0
        var items = 0
        var skipped: [String] = []
        var seenInodes = Set<UInt64>()
        let progress: @Sendable (ScanProgress) -> Void
        init(progress: @escaping @Sendable (ScanProgress) -> Void) { self.progress = progress }
    }

    public func scan(root: URL, progress: @escaping @Sendable (ScanProgress) -> Void = { _ in }) throws -> ScanResult {
        let state = State(progress: progress)
        let modified = try? root.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        let node = try visit(root, kind: .folder, modified: modified, insidePackage: false, state: state)
        progress(ScanProgress(bytes: state.bytes, items: state.items))
        return ScanResult(date: Date(), root: node, skipped: state.skipped)
    }

    private func visit(_ url: URL, kind: NodeKind, modified: Date?, insidePackage: Bool, state: State) throws -> ScanNode {
        try Task.checkCancellation()
        let entries: [URL]
        do {
            entries = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: Self.keys)
        } catch {
            state.skipped.append(url.path)
            return ScanNode(path: url.path, size: 0, kind: kind, modified: modified, largestChildFolder: 0, children: [])
        }

        var size: Int64 = 0
        var largestFolder: Int64 = 0
        var kept: [ScanNode] = []
        for listed in entries {
            guard let v = try? listed.resourceValues(forKeys: Set(Self.keys)), v.isSymbolicLink != true else { continue }
            // Child paths are built from the parent's path: the listing may spell the
            // same directory differently (/private/var vs /var), which would break
            // prefix matching in TopItems and applyDeletion.
            let entry = url.appending(path: listed.lastPathComponent)
            let child: ScanNode
            if v.isDirectory == true {
                let isPackage = !insidePackage && v.isPackage == true
                child = try visit(entry, kind: isPackage ? .package : .folder, modified: v.contentModificationDate,
                                  insidePackage: insidePackage || isPackage, state: state)
                if child.kind == .folder { largestFolder = max(largestFolder, child.size) }
            } else {
                child = ScanNode(path: entry.path, size: fileSize(entry, v, state), kind: .file,
                                 modified: v.contentModificationDate, largestChildFolder: 0, children: [])
            }
            size += child.size
            if !insidePackage, child.size >= keepThreshold { kept.append(child) }
        }

        if kind == .package { kept = []; largestFolder = 0 }
        kept.sort { $0.size > $1.size }
        return ScanNode(path: url.path, size: size, kind: kind, modified: modified,
                        largestChildFolder: largestFolder, children: kept)
    }

    private func fileSize(_ url: URL, _ v: URLResourceValues, _ state: State) -> Int64 {
        if (v.linkCount ?? 1) > 1 {
            var st = stat()
            if lstat(url.path, &st) == 0, !state.seenInodes.insert(UInt64(st.st_ino)).inserted { return 0 }
        }
        let size = Int64(v.totalFileAllocatedSize ?? v.fileAllocatedSize ?? 0)
        state.bytes += size
        state.items += 1
        if state.items % 5_000 == 0 { state.progress(ScanProgress(bytes: state.bytes, items: state.items)) }
        return size
    }
}
