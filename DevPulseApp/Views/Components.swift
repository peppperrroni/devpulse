import SwiftUI

struct Segmented<T: Hashable>: View {
    let options: [(T, String)]
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { i in
                let (value, title) = options[i]
                Button { selection = value } label: {
                    Text(title)
                        .font(Fonts.body(12, .medium))
                        .foregroundStyle(selection == value ? Theme.ink : Theme.mute)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 12)
                        .background {
                            if selection == value {
                                RoundedRectangle(cornerRadius: 6).fill(Theme.raised)
                                    .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.sunken))
    }
}

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(Fonts.mono(10, .medium))
            .tracking(0.8)
            .foregroundStyle(Theme.mute)
    }
}

struct GaugeCard: View {
    let title: String
    let value: String
    let fraction: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(Fonts.mono(11)).foregroundStyle(Theme.mute)
            Text(value).font(Fonts.display(17)).foregroundStyle(Theme.ink)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.sunken)
                    Capsule().fill(color).frame(width: geo.size.width * min(1, max(0, fraction)))
                }
            }
            .frame(height: 6)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.raised))
    }
}

struct NumberedRow: View {
    let index: Int
    let title: String
    let value: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(String(format: "%02d", index)).font(Fonts.mono(10)).foregroundStyle(Theme.mute).frame(width: 16)
                Text(title).font(Fonts.body(12.5)).foregroundStyle(Theme.ink).lineLimit(1).truncationMode(.middle)
                Spacer(minLength: 8)
                Text(value).font(Fonts.mono(11.5, .medium)).foregroundStyle(Theme.ink)
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 6)
            .background(RoundedRectangle(cornerRadius: 6).fill(hovering ? Theme.raised : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

struct DPButtonStyle: ButtonStyle {
    enum Kind { case plain, primary, danger }
    var kind: Kind = .plain
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Fonts.body(12, .semibold))
            .foregroundStyle(kind == .plain ? Theme.ink : (kind == .primary ? Theme.bg : Color.white))
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: 8).fill(background))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(kind == .plain ? Theme.sunken : .clear))
            .opacity(configuration.isPressed ? 0.75 : (isEnabled ? 1 : 0.4))
    }

    private var background: Color {
        switch kind {
        case .plain: Theme.raised
        case .primary: Theme.ink
        case .danger: Theme.danger
        }
    }
}
