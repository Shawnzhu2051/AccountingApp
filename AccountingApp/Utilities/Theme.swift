import SwiftUI
import Foundation

// MARK: - 颜色主题
extension Color {
    // 主色调
    static let accentBlue = Color(red: 0.2, green: 0.5, blue: 1.0)
    static let accentGreen = Color(red: 0.2, green: 0.8, blue: 0.4)
    static let accentRed = Color(red: 1.0, green: 0.3, blue: 0.3)
    static let accentOrange = Color(red: 1.0, green: 0.6, blue: 0.2)
    static let accentPurple = Color(red: 0.6, green: 0.4, blue: 0.9)

    // 背景色
    static let cardBackground = Color(.systemBackground)
    static let groupedBackground = Color(.systemGroupedBackground)

    // 图表配色
    static let chartColors: [Color] = [
        Color(red: 0.3, green: 0.6, blue: 1.0),
        Color(red: 0.3, green: 0.8, blue: 0.5),
        Color(red: 1.0, green: 0.6, blue: 0.3),
        Color(red: 0.8, green: 0.4, blue: 0.9),
        Color(red: 1.0, green: 0.4, blue: 0.5),
        Color(red: 0.4, green: 0.7, blue: 0.9),
        Color(red: 0.9, green: 0.7, blue: 0.3),
        Color(red: 0.5, green: 0.8, blue: 0.8)
    ]
}

// MARK: - 通知
extension Notification.Name {
    static let transactionsDidChange = Notification.Name("transactionsDidChange")
}

// MARK: - 视图修饰符
extension View {
    func cardStyle() -> some View {
        self
            .padding()
            .background(Color.cardBackground)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    func sectionCardStyle() -> some View {
        self
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color.cardBackground)
            .cornerRadius(12)
    }
}

// MARK: - 字体样式
extension Font {
    static let cardTitle = Font.system(size: 17, weight: .semibold)
    static let cardSubtitle = Font.system(size: 14, weight: .regular)
    static let currencyAmount = Font.system(size: 28, weight: .bold, design: .rounded)
    static let smallAmount = Font.system(size: 20, weight: .semibold, design: .rounded)
}
