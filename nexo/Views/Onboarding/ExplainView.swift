import SwiftUI

struct ExplainView: View {
    @State private var selectedRole: AppRole? = nil
    @State private var contentIn = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()

            VStack {
                LinearGradient(
                    colors: [Color.nexoMint.opacity(0.6), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 320)
                Spacer()
            }
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                Text("Elige tu modo")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.nexoBrand.opacity(0.5))
                    .padding(.bottom, 16)
                    .opacity(contentIn ? 1 : 0)

                Text("¿Cómo usas\nNEXO?")
                    .font(.system(size: 48, weight: .bold))
                    .tracking(-3)
                    .foregroundStyle(Color.nexoForest)
                    .opacity(contentIn ? 1 : 0)
                    .offset(y: contentIn ? 0 : 10)

                Rectangle()
                    .fill(Color.nexoForest.opacity(0.1))
                    .frame(height: 0.5)
                    .padding(.vertical, 20)
                    .opacity(contentIn ? 1 : 0)

                Text("Esto determina tu pantalla principal.\nPuedes cambiarlo después.")
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                    .lineSpacing(4)
                    .opacity(contentIn ? 1 : 0)
                    .offset(y: contentIn ? 0 : 8)

                Spacer()

                VStack(spacing: 10) {
                    RoleCard(
                        icon:         "house",
                        iconSelected: "house.fill",
                        title:        "Hogar, escuela o negocio",
                        description:  "Identifico residuos y los preparo para recolección.",
                        isSelected:   selectedRole == .hogar
                    ) {
                        withAnimation(.easeOut(duration: 0.2)) { selectedRole = .hogar }
                    }

                    RoleCard(
                        icon:         "figure.walk",
                        iconSelected: "figure.walk",        // sin .fill — no existe en SF Symbols
                        title:        "Soy recolector",
                        description:  "Busco materiales preparados cerca de mi ruta.",
                        isSelected:   selectedRole == .recolector
                    ) {
                        withAnimation(.easeOut(duration: 0.2)) { selectedRole = .recolector }
                    }

                    RoleCard(
                        icon:         "building.2",
                        iconSelected: "building.2.fill",
                        title:        "Empresa o comercio",
                        description:  "Publico lotes de residuos para gestores certificados.",
                        isSelected:   selectedRole == .empresa
                    ) {
                        withAnimation(.easeOut(duration: 0.2)) { selectedRole = .empresa }
                    }
                }
                .opacity(contentIn ? 1 : 0)
                .offset(y: contentIn ? 0 : 14)


                Spacer()

                VStack(spacing: 10) {
                    NavigationLink(destination: SignUpView()) {
                        Text(selectedRole == nil ? "Selecciona un modo" : "Continuar")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(selectedRole == nil ? Color(uiColor: .tertiaryLabel) : .white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                selectedRole == nil
                                    ? Color(uiColor: .secondarySystemBackground)
                                    : Color.nexoForest,
                                in: RoundedRectangle(cornerRadius: Rd.lg)
                            )
                            .animation(.easeOut(duration: 0.25), value: selectedRole == nil)
                    }
                    .disabled(selectedRole == nil)
                    .simultaneousGesture(TapGesture().onEnded {
                        guard let role = selectedRole else { return }
                        switch role {
                        case .hogar:      UserDefaults.standard.set("hogar",      forKey: "nexoRole")
                        case .recolector: UserDefaults.standard.set("recolector", forKey: "nexoRole")
                        case .empresa:    UserDefaults.standard.set("empresa",    forKey: "nexoRole")
                        }
                    })
                }
                .opacity(contentIn ? 1 : 0)
                .offset(y: contentIn ? 0 : 14)
                .padding(.bottom, 48)
            }
            .padding(.horizontal, Sp.lg)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Regresar")
                            .font(.system(size: 15, weight: .regular))
                    }
                    .foregroundStyle(Color.nexoForest)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.55).delay(0.1)) { contentIn = true }
        }
    }
}

// MARK: - RoleCard

struct RoleCard: View {
    let icon        : String
    let iconSelected: String   
    let title       : String
    let description : String
    let isSelected  : Bool
    let onTap       : () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Sp.md) {
                Image(systemName: isSelected ? iconSelected : icon)
                    .font(.system(size: 16, weight: isSelected ? .regular : .light))
                    .foregroundStyle(isSelected ? Color.nexoForest : Color(uiColor: .tertiaryLabel))
                    .frame(width: 28)
                    .animation(.easeOut(duration: 0.2), value: isSelected)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Color.nexoForest : Color(uiColor: .secondaryLabel))
                    Text(description)
                        .font(.system(size: 12, weight: .light))
                        .foregroundStyle(Color(uiColor: .tertiaryLabel))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                // Radio button
                ZStack {
                    Circle()
                        .strokeBorder(
                            isSelected ? Color.nexoForest : Color(uiColor: .separator),
                            lineWidth: isSelected ? 1.5 : 0.5
                        )
                        .frame(width: 20, height: 20)
                    if isSelected {
                        Circle()
                            .fill(Color.nexoForest)
                            .frame(width: 10, height: 10)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.easeOut(duration: 0.2), value: isSelected)
            }
            .padding(Sp.md)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Rd.md))
            .overlay(
                RoundedRectangle(cornerRadius: Rd.md)
                    .strokeBorder(
                        isSelected ? Color.nexoForest.opacity(0.3) : Color.nexoForest.opacity(0.07),
                        lineWidth: isSelected ? 1 : 0.5
                    )
            )
            .animation(.easeOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

enum AppRole {
    case hogar
    case recolector
    case empresa
}

#Preview {
    NavigationStack { ExplainView() }
}
