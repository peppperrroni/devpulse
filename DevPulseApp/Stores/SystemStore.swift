import DevPulseCore
import Observation

@Observable @MainActor
final class SystemStore {
    private(set) var snapshot = SystemSampler.sample()
    @ObservationIgnored var onChange: ((SystemSnapshot) -> Void)?
    @ObservationIgnored private var loop: Task<Void, Never>?

    func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.snapshot = SystemSampler.sample()
                self.onChange?(self.snapshot)
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }
}
