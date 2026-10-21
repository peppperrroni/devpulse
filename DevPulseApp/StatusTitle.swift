import AppKit
import DevPulseCore

/// "● 62% / ● 71%": coloured state dots, label-coloured text that adapts to the menu bar.
enum StatusTitle {
    static func make(_ s: SystemSnapshot) -> NSAttributedString {
        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let dotFont = NSFont.systemFont(ofSize: 8)
        let result = NSMutableAttributedString()
        func dot(_ health: Health) {
            result.append(NSAttributedString(string: "●", attributes: [
                .font: dotFont, .foregroundColor: health.nsColor, .baselineOffset: 1.5,
            ]))
        }
        func text(_ string: String, color: NSColor = .labelColor) {
            result.append(NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color]))
        }
        dot(s.ramHealth)
        text(" \(s.ramPercent)%")
        text(" / ", color: .tertiaryLabelColor)
        dot(s.diskHealth)
        text(" \(s.diskUsedPercent)%")
        return result
    }

    static func accessibilityLabel(_ s: SystemSnapshot) -> String {
        "DevPulse: память \(s.ramPercent)%, \(word(s.ramHealth)); диск занят на \(s.diskUsedPercent)%, \(word(s.diskHealth))"
    }

    private static func word(_ health: Health) -> String {
        switch health {
        case .good: "норма"
        case .warn: "внимание"
        case .bad: "критично"
        }
    }
}
