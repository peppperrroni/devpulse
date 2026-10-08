import Darwin
import Observation

enum CleanerTab: Hashable {
    case processes, files
}

@Observable @MainActor
final class Navigation {
    var tab: CleanerTab = .processes
    var selectedPIDs: Set<pid_t> = []
    var selectedPaths: Set<String> = []
}
