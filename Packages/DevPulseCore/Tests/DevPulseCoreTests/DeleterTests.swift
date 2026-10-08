import Testing
import Foundation
@testable import DevPulseCore

struct DeleterTests {
    @Test func deletesInsideHomeAndReportsFreed() throws {
        let t = try TempTree()
        let f = try t.file("cache/big.bin", bytes: 4096)
        let d = Deleter(home: t.root.path)
        let report = d.delete([TopItem(path: f.path, size: 4096, kind: .file)])
        #expect(report.freed == 4096)
        #expect(report.failures.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: f.path))
    }

    @Test func refusesOutsideHome() throws {
        let t = try TempTree()
        #expect(throws: DeleteRefusal.outsideHome) { try Deleter(home: t.root.path).validate("/usr/bin") }
    }

    @Test func refusesProtectedRootsAndTheirAncestors() throws {
        let t = try TempTree()
        _ = try t.dir("Library")
        let d = Deleter(home: t.root.path)
        #expect(throws: DeleteRefusal.protected) { try d.validate(t.root.appending(path: "Library").path) }
        #expect(throws: DeleteRefusal.outsideHome) { try d.validate(t.root.path) }   // home itself is not *inside* home
    }

    @Test func dotDotTraversalIsRefused() throws {
        let t = try TempTree()
        _ = try t.dir("Library/Developer")
        let d = Deleter(home: t.root.path)
        #expect(throws: DeleteRefusal.protected) { try d.validate(t.root.path + "/Library/Developer/..") }
        #expect(throws: DeleteRefusal.outsideHome) { try d.validate(t.root.path + "/Library/../..") }
    }

    @Test func relativePathsAreRefused() throws {
        // Relative input would resolve against the process cwd, not against home.
        let t = try TempTree()
        _ = try t.dir("Projects")
        let d = Deleter(home: t.root.path)
        FileManager.default.changeCurrentDirectoryPath(t.root.path)
        #expect(throws: DeleteRefusal.outsideHome) { try d.validate("Projects") }
        #expect(throws: DeleteRefusal.outsideHome) { try d.validate("Library/..") }
        #expect(throws: DeleteRefusal.outsideHome) { try d.validate("~/Library/Developer/../..") }
        #expect(FileManager.default.fileExists(atPath: t.root.appending(path: "Projects").path))
    }

    @Test func symlinkPointingOutsideIsRefused() throws {
        let t = try TempTree()
        let outside = try TempTree()
        try outside.file("victim.bin", bytes: 10)
        let link = t.root.appending(path: "link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside.root)
        #expect(throws: DeleteRefusal.outsideHome) { try Deleter(home: t.root.path).validate(link.path + "/victim.bin") }
        #expect(FileManager.default.fileExists(atPath: outside.root.appending(path: "victim.bin").path))
    }

    @Test func missingPathIsRefusedAndReported() throws {
        let t = try TempTree()
        let d = Deleter(home: t.root.path)
        let gone = t.root.appending(path: "gone").path
        #expect(throws: DeleteRefusal.missing) { try d.validate(gone) }
        let report = d.delete([TopItem(path: gone, size: 10, kind: .file)])
        #expect(report.freed == 0)
        #expect(report.failures.map(\.path) == [gone])
    }

    @Test func deleteRunsOffMainActor() async throws {
        let t = try TempTree()
        let f = try t.file("x.bin", bytes: 4096)
        let home = t.root.path
        let path = f.path
        let report = await Task.detached { Deleter(home: home).delete([TopItem(path: path, size: 4096, kind: .file)]) }.value
        #expect(report.deleted == [path])
    }
}
