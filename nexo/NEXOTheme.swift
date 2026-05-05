// NEXOTheme.swift
// Design tokens: colores, espaciado y radios para toda la app.

import SwiftUI

// MARK: - Colors
extension Color {
    static let nexoDark  = Color(hex: "214F4B")
    static let nexoBlue  = Color(hex: "A9DEF9")
    static let nexoAmber = Color(hex: "FACF00")
    static let nexoGreen = Color(hex: "45B15B")
    static let nexoDeep  = Color(hex: "004F2D")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Spacing
enum Sp {
    static let xs: CGFloat =  4
    static let sm: CGFloat =  8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Corner Radius
enum Rd {
    static let sm: CGFloat =  8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let pill: CGFloat = 100
}
