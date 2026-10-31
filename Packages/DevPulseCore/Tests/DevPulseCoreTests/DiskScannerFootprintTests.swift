import Testing
import Foundation
import Darwin
@testable import DevPulseCore

private func footprint() -> Int64 {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
    let kr = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
        }
    }
    return kr == KERN_SUCCESS ? Int64(info.phys_footprint) : -1
}

/// Without a per-directory autorelease pool the scan kept ~1 KB per file until it
/// finished (20 MB here, 2 GB on a real home folder).
@Test func scanDoesNotAccumulateMemoryWhileRunning() throws {
    let tree = try TempTree()
    for d in 0..<200 { for f in 0..<100 { try tree.file("d\(d)/f\(f)", bytes: 1) } }
    let before = footprint()
    _ = try DiskScanner().scan(root: tree.root)
    #expect(footprint() - before < 5_000_000)
}
