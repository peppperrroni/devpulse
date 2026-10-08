/// Named visible clients (popover, window). Idempotent per client, unlike a counter,
/// so a repeated show without a matching hide cannot keep sampling alive forever.
public struct VisibilityTracker: Sendable {
    private var clients: Set<String> = []

    public init() {}

    public var isActive: Bool { !clients.isEmpty }

    /// True when this show made the tracker active (start work).
    public mutating func show(_ client: String) -> Bool {
        let wasActive = isActive
        clients.insert(client)
        return !wasActive
    }

    /// True when this hide made the tracker inactive (stop work).
    public mutating func hide(_ client: String) -> Bool {
        guard clients.remove(client) != nil else { return false }
        return !isActive
    }
}
