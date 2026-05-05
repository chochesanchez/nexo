// NEXOTheme.swift
// Design tokens: colores, espaciado y radios para toda la app.

import SwiftUI

extension Color {
    static let nexoBlack   = Color(hex: "0A0A0A")
    static let nexoDeep    = Color(hex: "0D2B27")
    static let nexoSurface = Color(hex: "F5F5F3")
    static let nexoGreen   = Color(hex: "45B15B")
    static let nexoAmber   = Color(hex: "FACF00")
    static let nexoBlue    = Color(hex: "006D8F")
    static let nexoDark    = Color(hex: "0A0A0A")  // legacy alias

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

enum Sp {
    static let xs:  CGFloat =  4
    static let sm:  CGFloat =  8
    static let md:  CGFloat = 16
    static let lg:  CGFloat = 24
    static let xl:  CGFloat = 32
    static let xxl: CGFloat = 48
}

enum Rd {
    static let xs:   CGFloat =  4
    static let sm:   CGFloat =  6
    static let md:   CGFloat = 10
    static let lg:   CGFloat = 14
    static let pill: CGFloat = 100
}
