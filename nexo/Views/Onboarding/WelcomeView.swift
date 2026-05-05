//
//  WelcomeView.swift
//  nexo
//
//  Created by Grecia Saucedo on 04/05/26.
//
import SwiftUI

struct WelcomeView: View {
    @State private var logoIn    = false
    @State private var ruleIn    = false
    @State private var taglineIn = false
    @State private var btnsIn    = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.nexoBlack.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    Spacer()

                    // Eyebrow
                    Text("Mexico · 2026")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(2.5)
                        .foregroundStyle(Color.white.opacity(0.2))
                        .textCase(.uppercase)
                        .padding(.bottom, 20)
                        .opacity(logoIn ? 1 : 0)

                    // Logo
                    Text("NEXO")
                        .font(.system(size: 76, weight: .black))
                        .tracking(-5)
                        .foregroundStyle(.white)
                        .scaleEffect(logoIn ? 1 : 0.92, anchor: .leading)
                        .opacity(logoIn ? 1 : 0)

                    // Regla
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 0.5)
                        .padding(.top, 20)
                        .padding(.bottom, 20)
                        .scaleEffect(x: ruleIn ? 1 : 0, anchor: .leading)
                        .opacity(ruleIn ? 1 : 0)

                    // Tagline — peso light para contraste con el 900 del logo
                    Text("Tus residuos\ntodavía tienen\nuna ruta.")
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(Color.white.opacity(0.45))
                        .lineSpacing(5)
                        .opacity(taglineIn ? 1 : 0)
                        .offset(y: taglineIn ? 0 : 8)

                    Spacer()

                    // Botones
                    VStack(spacing: 10) {
                        NavigationLink(destination: ExplainView()) {
                            Text("Comenzar")
                                .font(.system(size: 13, weight: .bold))
                                .tracking(0.8)
                                .textCase(.uppercase)
                                .foregroundStyle(Color.nexoBlack)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color.nexoAmber)
                                .clipShape(RoundedRectangle(cornerRadius: Rd.sm))
                        }

                        NavigationLink(destination: LoginView()) {
                            Text("Ya tengo cuenta")
                                .font(.system(size: 13, weight: .regular))
                                .tracking(0.3)
                                .foregroundStyle(Color.white.opacity(0.3))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.white.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: Rd.sm))
                                .overlay(
                                    RoundedRectangle(cornerRadius: Rd.sm)
                                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                                )
                        }
                    }
                    .opacity(btnsIn ? 1 : 0)
                    .offset(y: btnsIn ? 0 : 12)
                    .padding(.bottom, 48)
                }
                .padding(.horizontal, Sp.lg)
            }
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.easeOut(duration: 0.5).delay(0.1))  { logoIn    = true }
                withAnimation(.easeOut(duration: 0.6).delay(0.35)) { ruleIn    = true }
                withAnimation(.easeOut(duration: 0.5).delay(0.5))  { taglineIn = true }
                withAnimation(.easeOut(duration: 0.4).delay(0.75)) { btnsIn    = true }
            }
        }
    }
}

#Preview { WelcomeView() }
