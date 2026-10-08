import AppKit
import CoreText
import DevPulseCore
import SwiftUI

enum Theme {
    static let bg = adaptive(0xF2F1EE, 0x101014)
    static let raised = adaptive(0xFAF9F7, 0x1A1A20)
    static let sunken = adaptive(0xE9E8E4, 0x0A0A0D)
    static let ink = adaptive(0x101014, 0xF2F1EE)
    static let mute = adaptive(0x6B6A66, 0x8D8C88)
    static let accent = Color(nsColor: NSColor(hex: 0x2D81FF))
    static let danger = Color(nsColor: NSColor(hex: 0xB3261E))

    static func nsColor(_ health: Health) -> NSColor {
        switch health {
        case .good: NSColor(hex: 0x4CAF50)
        case .warn: NSColor(hex: 0xFFB347)
        case .bad: NSColor(hex: 0xB3261E)
        }
    }

    static func color(_ health: Health) -> Color { Color(nsColor: nsColor(health)) }

    private static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(hex: dark) : NSColor(hex: light)
        })
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

enum Fonts {
    /// Inter and Geist Mono ship in the bundle; if registration fails SwiftUI falls back to SF.
    static func register() {
        for url in Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [] {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy).width(.expanded) }
    static func body(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { .custom("Inter", size: size).weight(weight) }
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { .custom("Geist Mono", size: size).weight(weight) }
    static func serif(_ size: CGFloat) -> Font { .system(size: size, design: .serif).italic() }
}

enum Fmt {
    static func bytes(_ value: Int64) -> String {
        let gb = Double(value) / 1_000_000_000
        return gb >= 1 ? String(format: "%.1f ГБ", gb) : String(format: "%.0f МБ", Double(value) / 1_000_000)
    }

    static func bytes(_ value: UInt64) -> String { bytes(Int64(clamping: value)) }

    static func ago(_ date: Date) -> String {
        let minutes = Int(Date().timeIntervalSince(date) / 60)
        if minutes < 1 { return "только что" }
        if minutes < 60 { return "\(minutes) мин назад" }
        if minutes < 60 * 24 { return "\(minutes / 60) ч назад" }
        return "\(minutes / 60 / 24) дн назад"
    }

    static func modified(_ date: Date?) -> String {
        guard let date else { return "—" }
        let days = Int(Date().timeIntervalSince(date) / 86_400)
        switch days {
        case ..<1: return "сегодня"
        case 1: return "вчера"
        case 2..<14: return "\(days) дн"
        case 14..<60: return "\(days / 7) нед"
        case 60..<730: return "\(days / 30) мес"
        default: return "\(days / 365) г"
        }
    }
}
