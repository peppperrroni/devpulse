import Testing
import Foundation
@testable import DevPulseCore

struct ScanCacheTests {
    private func f(_ p: String, _ s: Int64, largest: Int64 = 0, _ c: [ScanNode] = []) -> ScanNode {
        ScanNode(path: p, size: s, kind: .folder, modified: nil, largestChildFolder: largest, children: c)
    }

    var sample: ScanResult {
        let dd = f("/h/L/Dev/DD", 90)
        let other = f("/h/L/Dev/Other", 60)
        let dev = f("/h/L/Dev", 160, largest: 90, [dd, other])
        return ScanResult(date: Date(timeIntervalSince1970: 1_000), root: f("/h", 200, largest: 160, [f("/h/L", 160, largest: 160, [dev])]), skipped: ["/h/x"])
    }

    @Test func roundTrips() throws {
        let t = try TempTree()
        let cache = ScanCache(url: t.root.appending(path: "c/scan.json"))
        try cache.save(sample)
        #expect(cache.load() == sample)
    }

    @Test func corruptCacheIsDiscarded() throws {
        let t = try TempTree()
        let url = t.root.appending(path: "scan.json")
        try Data("{nope".utf8).write(to: url)
        #expect(ScanCache(url: url).load() == nil)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func wrongSchemaVersionIsDiscarded() throws {
        let t = try TempTree()
        let url = t.root.appending(path: "scan.json")
        var old = sample
        old.version = 0
        try ScanCache(url: url).save(old)
        #expect(ScanCache(url: url).load() == nil)
    }

    @Test func deletionSubtractsFromAncestors() {
        var r = sample
        r.applyDeletion(of: "/h/L/Dev/DD")
        #expect(r.root.size == 110)
        #expect(r.root.children[0].size == 70)
        #expect(r.root.children[0].children[0].size == 70)
        #expect(r.root.children[0].children[0].children.map(\.path) == ["/h/L/Dev/Other"])
    }

    @Test func deletionRecomputesLargestChild() {
        var r = sample
        r.applyDeletion(of: "/h/L/Dev/DD")
        let dev = r.root.children[0].children[0]
        #expect(dev.largestChildFolder == 60)
        #expect(r.root.children[0].largestChildFolder == 70)
    }

    @Test func deletingUnknownPathChangesNothing() {
        var r = sample
        r.applyDeletion(of: "/h/nope")
        #expect(r == sample)
    }
}
