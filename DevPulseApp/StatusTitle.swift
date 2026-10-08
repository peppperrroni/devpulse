import AppKit
import DevPulseCore

/// "● 62% / ● 71%": coloured dots, label-coloured text that adapts to the menu bar.
enum StatusTitle {
    static func make(_ s: SystemSnapshot) -> NSAttributedString {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        let dotFont = NSFont.systemFont(ofSize: 9)
        let result = NSMutableAttributedString()
        func dot(_ health: Health) {
            result.append(NSAttributedString(string: "●", attributes: [
                .font: dotFont, .foregroundColor: Theme.nsColor(health), .baselineOffset: 1,
            ]))
        }
        func text(_ string: String, color: NSColor = .labelColor) {
            result.append(NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color]))
        }
        dot(s.ramHealth)
        text(" \(s.ramPercent)%")
        text(" / ", color: .secondaryLabelColor)
        dot(s.diskHealth)
        text(" \(s.diskUsedPercent)%")
        return result
    }
}
