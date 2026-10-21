import AppKit
import DevPulseCore
import SwiftUI

extension Health {
    /// System semantic colours; used only where state matters (status dots, gauges).
    var nsColor: NSColor {
        switch self {
        case .good: .systemGreen
        case .warn: .systemOrange
        case .bad: .systemRed
        }
    }

    var color: Color { Color(nsColor: nsColor) }

    /// Gauge tint: neutral accent when fine, state colour only when it needs attention.
    var tint: Color { self == .good ? .accentColor : color }
}

enum Fmt {
    static func bytes(_ value: Int64) -> String {
        let gb = Double(value) / 1_000_000_000
        return gb >= 1 ? String(format: "%.1f ГБ", gb) : String(format: "%.0f МБ", Double(value) / 1_000_000)
    }

    /// RAM in binary units, as Activity Monitor shows it (16 GB Mac → "16.0 ГБ", not 17.2).
    static func memory(_ value: UInt64) -> String {
        let gib = Double(value) / 1_073_741_824
        return gib >= 1 ? String(format: "%.1f ГБ", gib) : String(format: "%.0f МБ", Double(value) / 1_048_576)
    }

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

    static func files(_ n: Int) -> String { plural(n, "файл", "файла", "файлов") }
    static func processes(_ n: Int) -> String { plural(n, "процесс", "процесса", "процессов") }

    /// Russian plural: 1 файл, 2 файла, 5 файлов, 11 файлов, 21 файл.
    static func plural(_ n: Int, _ one: String, _ few: String, _ many: String) -> String {
        let (mod10, mod100) = (n % 10, n % 100)
        let word = mod10 == 1 && mod100 != 11 ? one
            : (2...4).contains(mod10) && !(12...14).contains(mod100) ? few : many
        return "\(n.formatted()) \(word)"
    }
}

func abbreviate(_ path: String) -> String {
    let home = NSHomeDirectory()
    return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
}
