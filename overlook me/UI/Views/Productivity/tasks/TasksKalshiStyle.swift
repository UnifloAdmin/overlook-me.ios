import SwiftUI

enum TasksKalshiStyle {
    static let pageBackground = Color.white
    static let cardBackground = Color.white
    static let cardBorder = Color(red: 240 / 255, green: 240 / 255, blue: 240 / 255)

    static let primaryText = Color(red: 9 / 255, green: 9 / 255, blue: 11 / 255)
    static let secondaryText = Color(red: 113 / 255, green: 113 / 255, blue: 122 / 255)
    static let tertiaryText = Color(red: 161 / 255, green: 161 / 255, blue: 170 / 255)

    static let surfaceMuted = Color(red: 244 / 255, green: 244 / 255, blue: 245 / 255)
    static let surfaceHover = Color(red: 250 / 255, green: 250 / 255, blue: 250 / 255)
    static let divider = Color(red: 228 / 255, green: 228 / 255, blue: 231 / 255)

    static let done = Color(red: 22 / 255, green: 163 / 255, blue: 74 / 255)
    static let doneBg = Color(red: 220 / 255, green: 252 / 255, blue: 231 / 255)

    static let today = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255)
    static let todayBg = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255).opacity(0.15)

    static let danger = Color(red: 220 / 255, green: 38 / 255, blue: 38 / 255)
    static let dangerSoft = Color(red: 248 / 255, green: 113 / 255, blue: 113 / 255)
    static let dangerBg = Color(red: 254 / 255, green: 226 / 255, blue: 226 / 255)

    static let warning = Color(red: 251 / 255, green: 191 / 255, blue: 36 / 255)

    static let primaryButtonBg = primaryText
    static let primaryButtonFg = Color.white
    static let secondaryButtonBg = Color.white
    static let secondaryButtonFg = tertiaryText
}

extension View {
    func tasksDataCard(cornerRadius: CGFloat = 14) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(TasksKalshiStyle.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(TasksKalshiStyle.cardBorder, lineWidth: 1)
                    )
            )
    }
}
