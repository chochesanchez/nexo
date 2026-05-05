//
//  ChatBubbleExtensions.swift
//  nexo
//
//  Created by Grecia Saucedo on 04/05/26.
//
import SwiftUI

extension ChatBubble {
    public enum TailPosition {
        case trailingTop
        case trailingBottom
        case leadingTop
        case leadingBottom

        var isLeading: Bool {
            switch self {
            case .trailingTop, .trailingBottom: return false
            case .leadingTop, .leadingBottom:   return true
            }
        }
    }
}

extension View {
    public func chatBubble(
        position: ChatBubble.TailPosition,
        cornerRadius: Double,
        color: Color
    ) -> some View {
        self
            .padding(cornerRadius / 2)
            .background {
                ChatBubble(cornerRadius: cornerRadius)
                    .rotateChatBubble(position: position)
                    .foregroundColor(color)
            }
            .padding(position.isLeading ? .leading : .trailing, cornerRadius / 2)
    }

    public func rotateChatBubble(position: ChatBubble.TailPosition) -> some View {
        switch position {
        case .trailingTop:
            return self.rotation3DEffect(.init(degrees: 180), axis: (0, 0, 0))
        case .trailingBottom:
            return self.rotation3DEffect(.init(degrees: 180), axis: (1, 0, 0))
        case .leadingTop:
            return self.rotation3DEffect(.init(degrees: 180), axis: (0, 1, 0))
        case .leadingBottom:
            return self.rotation3DEffect(.init(degrees: 180), axis: (0, 0, 1))
        }
    }
}
