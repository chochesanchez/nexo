//
//  ExplainView.swift
//  nexo
//
//  Created by Grecia Saucedo on 04/05/26.
//
// ExplainView.swift — Rediseño Bateman/Apple
import SwiftUI

struct ExplainView: View {
    @State private var selectedRole: AppRole? = nil
    @State private var contentIn = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.nexoBlack.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {

                // Header
                VStack(alignment: .leading, spacing: 12) {
                    Text("¿Cómo usas NEXO?")
                        .font(.system(size: 36, weight: .black))
                        .tracking(-2)
                        .foregroundStyle(.white)

                    Text("Esto determina tu pantalla principal.\nPuedes cambiarlo después.")
                        .font(.system(size: 13, weight: .light))
                        .foregroundStyle(Color.white.opacity(0.35))
                        .lineSpacing(3)
                }
                .padding(.top, 80)
                .padding(.horizontal, Sp.lg)
                .padding(.bottom, 40)

                // Regla
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 0.5)
                    .padding(.horizontal, Sp.lg)
                    .padding(.bottom, 32)

                // Tarjetas de rol
                VStack(spacing: 10) {
                    RoleCard(
                        icon: "house",
                        title: "Hogar, escuela o negocio",
                        description: "Identifico residuos y los preparo para recolección.",
                        isSelected: selectedRole == .hogar
                    ) { withAnimation(.easeOut(duration: 0.2)) { selectedRole = .hogar } }

                    RoleCard(
                        icon: "figure.walk",
                        title: "Soy recolector",
                        description: "Busco materiales preparados cerca de mi ruta.",
                        isSelected: selectedRole == .recolector
                    ) { withAnimation(.easeOut(duration: 0.2)) { selectedRole = .recolector } }
                }
                .padding(.horizontal, Sp.lg)
                .opacity(contentIn ? 1 : 0)
                .offset(y: contentIn ? 0 : 16)

                Spacer()

                // CTA
                NavigationLink(destination: SignUpView()) {
                    Text(selectedRole == nil ? "Selecciona un modo" : "Continuar")
                        .font(.system(size: 13, weight: .bold))
                        .tracking(0.8)
                        .textCase(.uppercase)
                        .foregroundStyle(selectedRole == nil ? Color.white.opacity(0.2) : Color.nexoBlack)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(selectedRole == nil ? Color.white.opacity(0.05) : Color.nexoAmber)
                        .clipShape(RoundedRectangle(cornerRadius: Rd.sm))
                        .animation(.easeOut(duration: 0.25), value: selectedRole)
                }
                .disabled(selectedRole == nil)
                .padding(.horizontal, Sp.lg)
                .padding(.bottom, 48)
                .simultaneousGesture(TapGesture().onEnded {
                    if let role = selectedRole {
                        UserDefaults.standard.set(role == .hogar ? "hogar" : "recolector", forKey: "nexoRole")
                    }
                })
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.4))
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.15)) { contentIn = true }
        }
    }
}

// MARK: - RoleCard
struct RoleCard: View {
    let icon: String
    let title: String
    let description: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Sp.md) {
                // Ícono
                Image(systemName: isSelected ? icon + ".fill" : icon)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(isSelected ? Color.nexoAmber : Color.white.opacity(0.25))
                    .frame(width: 32)

                // Texto
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : Color.white.opacity(0.55))
                    Text(description)
                        .font(.system(size: 12, weight: .light))
                        .foregroundStyle(Color.white.opacity(0.25))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                // Indicador
                ZStack {
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(
                            isSelected ? Color.nexoAmber : Color.white.opacity(0.1),
                            lineWidth: isSelected ? 1.5 : 0.5
                        )
                        .frame(width: 18, height: 18)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.nexoAmber)
                    }
                }
            }
            .padding(Sp.md)
            .background(
                RoundedRectangle(cornerRadius: Rd.md)
                    .fill(isSelected ? Color.white.opacity(0.04) : Color.white.opacity(0.02))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Rd.md)
                    .strokeBorder(
                        isSelected ? Color.nexoAmber.opacity(0.4) : Color.white.opacity(0.06),
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

enum AppRole { case hogar, recolector }

#Preview {
    NavigationStack { ExplainView() }
}
