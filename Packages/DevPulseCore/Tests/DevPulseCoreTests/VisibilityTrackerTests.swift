import Testing
@testable import DevPulseCore

struct VisibilityTrackerTests {
    @Test func repeatedShowOfOneClientNeedsOneHide() {
        // Opening the cleaner while its window is minimized used to attach twice.
        var t = VisibilityTracker()
        #expect(t.show("window") == true)     // first client → start sampling
        #expect(t.show("window") == false)
        #expect(t.hide("window") == true)     // last client gone → stop sampling
        #expect(!t.isActive)
    }

    @Test func staysActiveWhileAnyClientIsVisible() {
        var t = VisibilityTracker()
        _ = t.show("popover")
        #expect(t.show("window") == false)
        #expect(t.hide("popover") == false)
        #expect(t.isActive)
        #expect(t.hide("window") == true)
    }

    @Test func hideWithoutShowIsANoOp() {
        var t = VisibilityTracker()
        #expect(t.hide("window") == false)
        #expect(!t.isActive)
    }
}
