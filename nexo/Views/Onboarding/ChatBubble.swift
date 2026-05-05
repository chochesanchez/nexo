//
//  ChatBublle.swift
//  nexo
//
//  Created by Grecia Saucedo on 04/05/26.
//
import SwiftUI

public struct ChatBubble: Shape {
    var cornerRadius: Double

    public init(cornerRadius: Double) {
        self.cornerRadius = cornerRadius
    }

    public func path(in rect: CGRect) -> Path {
        Path { path in
            let tailSize = cornerRadius / 2

            path.addArc(
                center: CGPoint(x: rect.minX + cornerRadius, y: rect.minY + cornerRadius),
                radius: cornerRadius,
                startAngle: Angle(degrees: 180),
                endAngle: Angle(degrees: 270),
                clockwise: false
            )
            path.addArc(
                center: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY + cornerRadius),
                radius: cornerRadius,
                startAngle: Angle(degrees: 270),
                endAngle: Angle(degrees: 270 + 45),
                clockwise: false
            )
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX + tailSize / 2, y: rect.minY),
                control: CGPoint(x: rect.maxX, y: rect.minY)
            )
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY + tailSize * 2),
                control: CGPoint(x: rect.maxX, y: rect.minY + tailSize)
            )
            path.addArc(
                center: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY - cornerRadius),
                radius: cornerRadius,
                startAngle: Angle(degrees: 0),
                endAngle: Angle(degrees: 90),
                clockwise: false
            )
            path.addArc(
                center: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY - cornerRadius),
                radius: cornerRadius,
                startAngle: Angle(degrees: 90),
                endAngle: Angle(degrees: 180),
                clockwise: false
            )
        }
    }
}
