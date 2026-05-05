//
//  WelcomeView.swift
//  nexo
//
//  Created by Grecia Saucedo on 04/05/26.
//

import SwiftUI

struct WelcomeView: View {
    @State private var contentIn = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Fondo: blanco puro con tinte verde apenas perceptible en el top
                Color(uiColor: .systemBackground).ignoresSafeArea()

                // Decoración top — gradiente verde muy sutil
                VStack {
                    LinearGradient(
                        colors: [Color.nexoMint.opacity(0.6), Color.clear],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 320)
                    Spacer()
                }
                .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    Spacer()

                    // Eyebrow
                    Text("Mexico · 2026")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.nexoBrand.opacity(0.5))
                        .padding(.bottom, 16)

                    // Logo
                    Text("NEXO")
                        .font(.system(size: 72, weight: .bold))
                        .tracking(-4)
                        .foregroundStyle(Color.nexoForest)
                        .opacity(contentIn ? 1 : 0)
                        .offset(y: contentIn ? 0 : 10)

                    // Regla verde muy sutil
                    Rectangle()
                        .fill(Color.nexoForest.opacity(0.1))
                        .frame(height: 0.5)
                        .padding(.vertical, 20)
                        .opacity(contentIn ? 1 : 0)

                    // Tagline
                    Text("Tus residuos\ntodavía tienen\nuna ruta.")
                        .font(.system(size: 20, weight: .light))
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                        .lineSpacing(4)
                        .opacity(contentIn ? 1 : 0)
                        .offset(y: contentIn ? 0 : 8)

                    Spacer()

                    // Bloque de acciones — liquid glass card
                    VStack(spacing: 10) {
                        NavigationLink(destination: ExplainView()) {
                            Text("Comenzar")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(
                                    Color.nexoForest,
                                    in: RoundedRectangle(cornerRadius: Rd.lg)
                                )
                        }

                        NavigationLink(destination: LoginView()) {
                            Text("Ya tengo cuenta")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(Color.nexoBrand)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(
                                    .regularMaterial,
                                    in: RoundedRectangle(cornerRadius: Rd.lg)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: Rd.lg)
                                        .strokeBorder(Color.nexoForest.opacity(0.12), lineWidth: 0.5)
                                )
                        }
                    }
                    .opacity(contentIn ? 1 : 0)
                    .offset(y: contentIn ? 0 : 14)
                    .padding(.bottom, 48)
                }
                .padding(.horizontal, Sp.lg)
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.55).delay(0.1)) { contentIn = true }
            }
        }
    }
}

#Preview { WelcomeView() }
