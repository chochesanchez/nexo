//
//  ExplainView.swift
//  nexo
//
//  Created by Grecia Saucedo on 04/05/26.
//
import SwiftUI

// MARK: - Explain View
struct ExplainView: View {
    @State private var selectedRole: AppRole? = nil
    @State private var contentOpacity: Double = 0
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {

            // MARK: Header
            ZStack(alignment: .bottomLeading) {
                Color.nexoGreen
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)

                VStack(alignment: .leading, spacing: Sp.xs) {
                    Text("¿Cómo vas a\nusar NEXO?")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundColor(.nexoDeep)
                        .lineSpacing(2)

                }
                .padding(.horizontal, Sp.lg)
                .padding(.bottom, Sp.sm)
                .padding(.top, 60) // empuja el texto debajo del Dynamic Island
            }

            WaveShape()
                .fill(Color.nexoGreen)
                .frame(height: 36)
                .offset(y: -1)

            // MARK: Contenido
            VStack(spacing: Sp.lg) {

                Text("NEXO identifica tus residuos, te dice cómo prepararlos y los conecta con recolectores cercanos.")
                    .font(.system(size: 18, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, Sp.lg)

                // MARK: Tarjetas
                VStack(spacing: Sp.md) {
                    RoleCard(
                        icon: "house.fill",
                        title: "Hogar, escuela o negocio",
                        description: "Escaneo residuos y los preparo para que los recojan.",
                        isSelected: selectedRole == .hogar
                    ) { selectedRole = .hogar }

                    RoleCard(
                        icon: "figure.walk",
                        title: "Soy recolector",
                        description: "Busco materiales preparados cerca de mi ruta.",
                        isSelected: selectedRole == .recolector
                    ) { selectedRole = .recolector }
                }
                .padding(.horizontal, Sp.lg)

                Spacer()

                // MARK: Boton cuenta
                NavigationLink(destination: SignUpView()) {
                    Text("Crear mi cuenta")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.nexoGreen)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(selectedRole == nil ? Color(.systemGray4) : Color.nexoDeep)
                        .clipShape(Capsule())
                }
                .disabled(selectedRole == nil)
                .opacity(selectedRole == nil ? 0.4 : 1)
                .animation(.easeInOut(duration: 0.2), value: selectedRole)
                .padding(.horizontal, Sp.lg)
                .padding(.bottom, Sp.xxl)
                .simultaneousGesture(TapGesture().onEnded {
                    if let role = selectedRole {
                        UserDefaults.standard.set(role == .hogar ? "hogar" : "recolector", forKey: "nexoRole")
                    }
                })
            }
            .padding(.top, Sp.lg)
            .opacity(contentOpacity)
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.nexoDeep)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                contentOpacity = 1
            }
        }
    }
}

// MARK: - Role Card
struct RoleCard: View {
    let icon: String
    let title: String
    let description: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Sp.md) {

                // SF Symbol
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isSelected ? .nexoDeep : Color(.systemGray2))
                    .frame(width: 36, height: 36)

                // Texto
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text(description)
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                // Radio button
                ZStack {
                    Circle()
                        .strokeBorder(
                            isSelected ? Color.nexoDeep : Color(.systemGray4),
                            lineWidth: 2
                        )
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(Color.nexoDeep)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(Sp.md)
            .background(
                RoundedRectangle(cornerRadius: Rd.md)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: Rd.md)
                            .strokeBorder(
                                isSelected ? Color.nexoDeep : Color.clear,
                                lineWidth: 1.5
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - App Role
enum AppRole {
    case hogar
    case recolector
}

// MARK: - Preview
#Preview {
    NavigationStack {
        ExplainView()
    }
}
