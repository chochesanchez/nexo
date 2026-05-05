//
//  WelcomeView.swift
//  nexo
//
//  Created by Grecia Saucedo on 04/05/26.
//
import SwiftUI

// MARK: - Wave shape
struct WaveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.height * 0.3),
            control1: CGPoint(x: rect.maxX * 0.35, y: rect.height),
            control2: CGPoint(x: rect.maxX * 0.65, y: 0)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: 0))
        path.closeSubpath()
        return path
    }
}

// MARK: - Welcome View
struct WelcomeView: View {
    @State private var mascotScale: CGFloat = 4
    @State private var mascotOffset: CGFloat = 1
    @State private var bubbleOpacity: Double = 0
    @State private var bubbleScale: CGFloat = 1
    @State private var buttonOpacity: Double = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()

                VStack(spacing: 0) {

                    // MARK: Header
                    ZStack(alignment: .bottomLeading) {
                        Color.nexoGreen
                            .frame(maxWidth: .infinity)
                            .frame(height: 220)

                        VStack(alignment: .leading, spacing: Sp.xs) {
                            Text("NEXO")
                                .font(.system(size: 70, weight: .black, design: .rounded))
                                .foregroundColor(.nexoDeep)
                                .tracking(-2)

                            Text("Conectando tus residuos\ncon su valor")
                                .font(.system(size: 20, weight: .regular, design: .rounded))
                                .foregroundColor(.nexoDeep.opacity(0.8))
                                .lineSpacing(3)
                        }
                        .padding(.horizontal, Sp.lg)
                        .padding(.bottom, Sp.lg)
                    }

                    // MARK: Wave
                    WaveShape()
                        .fill(Color.nexoGreen)
                        .frame(height: 40)
                        .offset(y: -1)

                    // MARK: Mascota + Bubble
                    ZStack(alignment: .top) {
                        VStack {
                            Spacer()
                            Image("fingerUp")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 300)
                                .scaleEffect(mascotScale)
                                .offset(y: mascotOffset)
                            Spacer()
                        }

                        // Bubble arriba a la derecha de la mascota
                        HStack {
                            Spacer()
                            Text("¡Aquí tus residuos sí valen!")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(.nexoDeep)
                                .fixedSize(horizontal: false, vertical: true)
                                .chatBubble(
                                    position: .leadingBottom,
                                    cornerRadius: 25,
                                    color: .nexoAmber
                                )
                                .frame(width: 160)
                                .opacity(bubbleOpacity)
                                .scaleEffect(bubbleScale, anchor: .bottomLeading)
                                .offset(x: -Sp.lg, y: 40)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, Sp.lg)


                    // MARK: Botón
                    VStack(spacing: 1) {
                        NavigationLink(destination: ExplainView()) {
                            Text("Empezar")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundColor(.nexoGreen)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.nexoDeep)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, Sp.lg)
                    .padding(.bottom, Sp.xxl)
                    .opacity(buttonOpacity)
                }
            }
            .ignoresSafeArea(edges: .top)
            .onAppear {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.65).delay(0.1)) {
                    mascotScale  = 1.0
                    mascotOffset = 0
                }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.65)) {
                    bubbleOpacity = 1
                    bubbleScale   = 1.0
                }
                withAnimation(.easeOut(duration: 0.4).delay(0.85)) {
                    buttonOpacity = 1
                }
            }
        }
    }
}

#Preview {
    WelcomeView()
}
