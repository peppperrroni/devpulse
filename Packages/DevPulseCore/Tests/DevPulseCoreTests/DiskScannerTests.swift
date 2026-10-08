import Testing
import Foundation
import Synchronization
@testable import DevPulseCore

final class TempTree {
    let root: URL
    init() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "dp-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    deinit { try? FileManager.default.removeItem(at: root) }

    @discardableResult
    func file(_ rel: String, bytes: Int) throws -> URL {
        let url = root.appending(path: rel)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 0xAB, count: bytes).write(to: url)
        return url
    }

    func dir(_ rel: String) throws -> URL {
        let url = root.appending(path: rel)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

func node(_ result: ScanResult, _ suffix: String) -> ScanNode? {
    func find(_ n: ScanNode) -> ScanNode? {
        if n.path.hasSuffix(suffix) { return n }
        for c in n.children { if let f = find(c) { return f } }
        return nil
    }
    return find(result.root)
}

struct DiskScannerTests {
    let mb = 1_048_576

    @Test func sumsSizesAndPrunesSmallNodes() throws {
        let t = try TempTree()
        try t.file("big/a.bin", bytes: 3 * mb)
        try t.file("big/b.bin", bytes: 1 * mb)
        try t.file("small/c.bin", bytes: 64 * 1024)
        let r = try DiskScanner(keepThreshold: 2 * Int64(mb)).scan(root: t.root)
        #expect(r.root.size >= Int64(4 * mb))
        #expect(node(r, "/big")?.kind == .folder)
        #expect(node(r, "/big/a.bin")?.kind == .file)
        #expect(node(r, "/big/b.bin") == nil)          // below threshold
        #expect(node(r, "/small") == nil)
        #expect(r.root.largestChildFolder == node(r, "/big")?.size)
    }

    @Test func packageIsOneItem() throws {
        let t = try TempTree()
        try t.file("Tool.app/Contents/MacOS/tool", bytes: 3 * mb)
        let r = try DiskScanner(keepThreshold: Int64(mb)).scan(root: t.root)
        let app = node(r, "/Tool.app")
        #expect(app?.kind == .package)
        #expect(app?.children.isEmpty == true)
        #expect((app?.size ?? 0) >= Int64(3 * mb))
        #expect(r.root.largestChildFolder == 0)        // packages are not folders
    }

    @Test func hardLinkCountedOnce() throws {
        let t = try TempTree()
        let a = try t.file("a.bin", bytes: 2 * mb)
        try FileManager.default.linkItem(at: a, to: t.root.appending(path: "b.bin"))
        let r = try DiskScanner(keepThreshold: 0).scan(root: t.root)
        #expect(r.root.size < Int64(3 * mb))
    }

    @Test func symlinksAreNotFollowed() throws {
        let t = try TempTree()
        let loop = try t.dir("loop")
        try FileManager.default.createSymbolicLink(at: loop.appending(path: "self"), withDestinationURL: loop)
        try t.file("loop/x.bin", bytes: mb)
        let r = try DiskScanner(keepThreshold: 0).scan(root: t.root)
        #expect(r.root.size < Int64(2 * mb))
    }

    @Test func unreadableFolderIsSkipped() throws {
        let t = try TempTree()
        let locked = try t.dir("locked")
        try t.file("locked/x.bin", bytes: mb)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path) }
        let r = try DiskScanner(keepThreshold: 0).scan(root: t.root)
        #expect(r.skipped.contains(locked.path))
    }

    @Test func honoursCancellation() async throws {
        let t = try TempTree()
        for i in 0..<50 { try t.file("d\(i)/f.bin", bytes: 4096) }
        let root = t.root
        let task = Task.detached { () throws -> ScanResult in
            withUnsafeCurrentTask { $0?.cancel() }
            return try DiskScanner(keepThreshold: 0).scan(root: root)
        }
        await #expect(throws: CancellationError.self) { try await task.value }
    }

    @Test func reportsFinalProgress() throws {
        let t = try TempTree()
        try t.file("a.bin", bytes: 4096)
        try t.file("b.bin", bytes: 4096)
        let seen = Mutex<[ScanProgress]>([])
        _ = try DiskScanner(keepThreshold: 0).scan(root: t.root) { p in seen.withLock { $0.append(p) } }
        #expect(seen.withLock { $0.last?.items } == 2)
    }
}
