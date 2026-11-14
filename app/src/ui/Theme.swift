import SwiftUI

/// Палитра из макета. Контраст проверен по ГОСТ Р 52872-2019 (AA): все пары не ниже 4,5 : 1.
enum Theme {
    static let window = Color(hex: 0x12141A)
    static let panel = Color(hex: 0x1C202B)
    static let row = Color(hex: 0x242938)
    static let stroke = Color(hex: 0x323A4D)
    static let text = Color(hex: 0xE9ECF2)
    static let dim = Color(hex: 0x98A0B3)
    static let accent = Color(hex: 0x04D9E7)
    static let ok = Color(hex: 0x3DDC97)
    static let warn = Color(hex: 0xFFB020)

    static let mono = Font.system(size: 13, design: .monospaced)
    static let monoSmall = Font.system(size: 12, design: .monospaced)
    static let label = Font.system(size: 12)
    static let value = Font.system(size: 13)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// Плашка-заголовок раздела.
struct SectionTitle: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .medium))
            .kerning(1)
            .foregroundStyle(Theme.dim)
    }
}

/// Строка «подпись — значение» в панели настроек.
struct LabeledValue: View {
    let label: String
    let value: String
    var valueColor: Color = Theme.text

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(Theme.label)
                .foregroundStyle(Theme.dim)
                .frame(width: 168, alignment: .leading)
                .lineLimit(1)
            Text(value)
                .font(Theme.monoSmall)
                .foregroundStyle(valueColor)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.vertical, 3)
    }
}
