// SignUpView.swift — Corporate redesign, liquid glass, light mode
import SwiftUI
import PhotosUI

struct SignUpView: View {
    @EnvironmentObject var auth: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var nombre    = ""
    @State private var apellido  = ""
    @State private var email     = ""
    @State private var telefono  = ""
    @State private var edadText  = ""
    @State private var password  = ""
    @State private var localError: String?
    @State private var isLoading = false

    @State private var avatarItem: PhotosPickerItem? = nil
    @State private var avatarData: Data?             = nil
    @State private var showSuccessToast              = false

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Crea tu cuenta")
                            .font(.system(size: 32, weight: .bold))
                            .tracking(-1)
                            .foregroundStyle(Color(uiColor: .label))
                        Text("Solo tarda un momento.")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(Color(uiColor: .secondaryLabel))
                    }
                    .padding(.top, 72)
                    .padding(.horizontal, Sp.lg)
                    .padding(.bottom, 28)

                    // Avatar — liquid glass card
                    PhotosPicker(selection: $avatarItem, matching: .images) {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color.nexoMint)
                                    .frame(width: 52, height: 52)
                                if let data = avatarData, let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 52, height: 52)
                                        .clipShape(Circle())
                                } else {
                                    Image(systemName: "person")
                                        .font(.system(size: 20, weight: .light))
                                        .foregroundStyle(Color.nexoBrand)
                                }
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Foto de perfil")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color(uiColor: .label))
                                Text("Opcional")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color(uiColor: .tertiaryLabel))
                        }
                        .padding(Sp.md)
                        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: Rd.lg))
                        .overlay(
                            RoundedRectangle(cornerRadius: Rd.lg)
                                .strokeBorder(Color(uiColor: .separator), lineWidth: 0.5)
                        )
                    }
                    .padding(.horizontal, Sp.lg)
                    .padding(.bottom, Sp.md)
                    .onChange(of: avatarItem) { _, item in
                        Task { avatarData = try? await item?.loadTransferable(type: Data.self) }
                    }

                    // Sección: Nombre
                    formSection("Datos personales") {
                        HStack(spacing: 10) {
                            formField("Nombre", text: $nombre)
                            formField("Apellido", text: $apellido)
                        }
                        formDivider
                        formField("Edad", text: $edadText)
                            .keyboardType(.numberPad)
                    }
                    .padding(.bottom, Sp.md)

                    // Sección: Contacto
                    formSection("Contacto") {
                        formField("Correo electrónico", text: $email)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        formDivider
                        formField("Teléfono (opcional)", text: $telefono)
                            .keyboardType(.phonePad)
                    }
                    .padding(.bottom, Sp.md)

                    // Sección: Seguridad
                    formSection("Seguridad") {
                        secureFormField("Contraseña", text: $password)
                    }
                    .padding(.bottom, Sp.lg)

                    // Error
                    if let error = localError ?? auth.errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(.red)
                        }
                        .padding(.horizontal, Sp.lg)
                        .padding(.bottom, Sp.md)
                    }

                    // CTA
                    Button { createAccount() } label: {
                        Group {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Crear cuenta")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.nexoForest, in: RoundedRectangle(cornerRadius: Rd.lg))
                        // Liquid glass shadow verde
                        .shadow(color: Color.nexoForest.opacity(0.25), radius: 12, x: 0, y: 4)
                    }
                    .disabled(isLoading)
                    .padding(.horizontal, Sp.lg)
                    .padding(.bottom, 16)

                    // Disclaimer
                    Text("Al crear tu cuenta aceptas que tus datos son usados únicamente para conectar residuos con recolectores.")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color(uiColor: .tertiaryLabel))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Sp.xl)
                        .padding(.bottom, 48)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Regresar")
                            .font(.system(size: 16, weight: .regular))
                    }
                    .foregroundStyle(Color.nexoBrand)
                }
            }
        }
        .overlay(alignment: .top) {
            if showSuccessToast {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white)
                    Text("Cuenta creada. Ahora inicia sesión.")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.nexoForest, in: Capsule())
                .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
                .padding(.top, 60)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onChange(of: auth.signupCompleted) { _, completed in
            if completed {
                withAnimation(.spring(response: 0.4)) { showSuccessToast = true }
                Task {
                    try? await Task.sleep(nanoseconds: 1_400_000_000)
                    auth.signupCompleted = false
                    dismiss()
                }
            }
        }
    }

    // MARK: - Form Section helper — liquid glass grouped style
    private func formSection<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(Color(uiColor: .secondaryLabel))
                .padding(.horizontal, Sp.lg)

            VStack(spacing: 0) {
                content()
            }
            .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: Rd.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Rd.lg)
                    .strokeBorder(Color(uiColor: .separator), lineWidth: 0.5)
            )
            .padding(.horizontal, Sp.lg)
        }
    }

    private var formDivider: some View {
        Rectangle()
            .fill(Color(uiColor: .separator))
            .frame(height: 0.5)
            .padding(.leading, Sp.md)
    }

    private func formField(_ label: String, text: Binding<String>) -> some View {
        TextField(label, text: text)
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(Color(uiColor: .label))
            .padding(.horizontal, Sp.md)
            .frame(height: 50)
            .tint(Color.nexoBrand)
    }

    private func secureFormField(_ label: String, text: Binding<String>) -> some View {
        SecureField(label, text: text)
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(Color(uiColor: .label))
            .padding(.horizontal, Sp.md)
            .frame(height: 50)
            .tint(Color.nexoBrand)
    }

    // MARK: - Lógica
    private func createAccount() {
        localError = nil
        auth.errorMessage = nil

        guard !nombre.isEmpty, !apellido.isEmpty, !email.isEmpty, !password.isEmpty else {
            localError = "Completa todos los campos."
            return
        }
        guard let edad = Int(edadText), edad >= 18 else {
            localError = "Debes tener 18 años o más."
            return
        }

        Task {
            isLoading = true
            await auth.signUp(
                nombre    : nombre,
                apellido  : apellido,
                email     : email,
                telefono  : telefono,
                edad      : edad,
                password  : password,
                avatarData: avatarData
            )
            isLoading = false
        }
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
