import Testing
import Foundation
@testable import DevPulseCore

private func folder(_ path: String, _ size: Int64, largest: Int64 = 0, _ children: [ScanNode] = []) -> ScanNode {
    ScanNode(path: path, size: size, kind: .folder, modified: nil, largestChildFolder: largest, children: children)
}
private func file(_ path: String, _ size: Int64, kind: NodeKind = .file) -> ScanNode {
    ScanNode(path: path, size: size, kind: kind, modified: nil, largestChildFolder: 0, children: [])
}

struct TopItemsTests {
    let home = "/Users/u"

    // ~ (200) ─ Library (150, protected) ─ Developer (100) ─ DerivedData (90) ─ ProjA (40), ProjB (40)
    //        └ dl.xip file (30)              └ Caches (50) split evenly
    var tree: ScanNode {
        let derived = folder("/Users/u/Library/Developer/DerivedData", 90, largest: 40, [
            folder("/Users/u/Library/Developer/DerivedData/ProjA", 40, largest: 5),
            folder("/Users/u/Library/Developer/DerivedData/ProjB", 40, largest: 5),
        ])
        let developer = folder("/Users/u/Library/Developer", 100, largest: 90, [derived])
        let caches = folder("/Users/u/Library/Caches", 50, largest: 20)
        let library = folder("/Users/u/Library", 150, largest: 100, [developer, caches])
        return folder(home, 200, largest: 150, [library, file("/Users/u/dl.xip", 30)])
    }

    @Test func folderDominatedByOneChildIsNotACandidate() {
        let paths = TopItems.folders(in: tree, home: home, limit: 10).map(\.path)
        #expect(!paths.contains("/Users/u/Library/Developer"))
        #expect(paths.first == "/Users/u/Library/Developer/DerivedData")
    }

    @Test func descendantsOfChosenFolderAreExcluded() {
        let paths = TopItems.folders(in: tree, home: home, limit: 10).map(\.path)
        #expect(!paths.contains("/Users/u/Library/Developer/DerivedData/ProjA"))
        #expect(paths == ["/Users/u/Library/Developer/DerivedData", "/Users/u/Library/Caches"])
    }

    @Test func protectedRootsAreNeverCandidates() {
        let flat = folder(home, 100, largest: 10, [folder("/Users/u/Library", 90, largest: 10)])
        #expect(TopItems.folders(in: flat, home: home, limit: 10).isEmpty)
    }

    @Test func childAtExactlyHalfDisqualifiesParent() {
        let t = folder(home, 100, largest: 100, [folder("/Users/u/p", 100, largest: 50, [folder("/Users/u/p/a", 50)])])
        let paths = TopItems.folders(in: t, home: home, limit: 10).map(\.path)
        #expect(!paths.contains("/Users/u/p"))
        #expect(paths.contains("/Users/u/p/a"))
    }

    @Test func filesIncludePackagesSortedBySize() {
        let t = folder(home, 100, largest: 0, [file("/Users/u/a.bin", 10), file("/Users/u/X.app", 40, kind: .package)])
        #expect(TopItems.files(in: t, limit: 5).map(\.path) == ["/Users/u/X.app", "/Users/u/a.bin"])
    }

    @Test func allMergesBySizeAndRespectsLimit() {
        let all = TopItems.all(in: tree, home: home, limit: 2)
        #expect(all.map(\.path) == ["/Users/u/Library/Developer/DerivedData", "/Users/u/Library/Caches"])
        let three = TopItems.all(in: tree, home: home, limit: 3)
        #expect(three.last?.path == "/Users/u/dl.xip")
    }

    @Test func protectedAncestorCheck() {
        #expect(ProtectedPaths.isProtected("/Users/u/Library", home: home))
        #expect(!ProtectedPaths.isProtected("/Users/u/Library/Caches", home: home))
        #expect(ProtectedPaths.isProtectedOrAncestor("/Users", home: home))
        #expect(!ProtectedPaths.isProtectedOrAncestor("/Users/u/Library/Caches", home: home))
    }
}
