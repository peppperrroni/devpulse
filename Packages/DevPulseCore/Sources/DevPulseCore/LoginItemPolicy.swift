public enum LoginItemPolicy {
    /// Register as a login item once, on the first launch of the installed copy.
    /// Later launches leave the user's on/off choice alone; development builds
    /// (anywhere outside /Applications) are never registered.
    public static func shouldAutoRegister(bundlePath: String, alreadyConfigured: Bool) -> Bool {
        !alreadyConfigured && bundlePath.hasPrefix("/Applications/")
    }
}
