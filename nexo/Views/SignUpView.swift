import SwiftUI
import PhotosUI

struct SignUpView: View {
    @EnvironmentObject var auth: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var nombre = ""
    @State private var apellido = ""
    @State private var email = ""
    @State private var telefono = ""
    @State private var edadText = ""
    @State private var password = ""
    @State private var localError: String?
    @State private var isLoading = false

    @State private var avatarItem: PhotosPickerItem? = nil
    @State private var avatarData: Data? = nil

    var body: some View {
        ZStack(alignment: .top) {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {

                VStack(alignment: .leading, spacing: Sp.xs) {
                    Text("Crea tu cuenta")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundColor(.nexoDeep)

                    Text("Solo tarda un momento.")
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Sp.lg)
                .padding(.top, 72)
                .padding(.bottom, Sp.xl)

                ZStack(alignment: .top) {
                    Color.nexoGreen
                        .clipShape(
                            RoundedCorner(radius: 32, corners: [.topLeft, .topRight])
                        )
                        .ignoresSafeArea(edges: .bottom)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: Sp.md) {

                            PhotosPicker(selection: $avatarItem, matching: .images) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.95))
                                        .frame(width: 88, height: 88)

                                    if let data = avatarData, let uiImage = UIImage(data: data) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 88, height: 88)
                                            .clipShape(Circle())
                                    } else {
                                        Image(systemName: "person.crop.circle.badge.plus")
                                            .font(.system(size: 38))
                                            .foregroundColor(.nexoDeep.opacity(0.7))
                                    }
                                }
                            }
                            .onChange(of: avatarItem) { _, item in
                                Task {
                                    avatarData = try? await item?.loadTransferable(type: Data.self)
                                }
                            }

                            HStack(spacing: Sp.sm) {
                                signUpField("Nombre", text: $nombre)
                                signUpField("Apellido", text: $apellido)
                            }

                            signUpField("Correo electrónico", text: $email)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)

                            signUpField("Teléfono", text: $telefono)
                                .keyboardType(.phonePad)

                            signUpField("Edad", text: $edadText)
                                .keyboardType(.numberPad)

                            signUpSecureField("Contraseña", text: $password)

                            if let error = localError ?? auth.errorMessage {
                                HStack(spacing: Sp.sm) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundColor(.white)

                                    Text(error)
                                        .font(.system(size: 13, design: .rounded))
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            Button {
                                createAccount()
                            } label: {
                                if isLoading {
                                    ProgressView()
                                        .tint(.nexoGreen)
                                } else {
                                    Text("Crear cuenta")
                                }
                            }
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.nexoGreen)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.nexoDeep)
                            .clipShape(Capsule())
                            .padding(.top, Sp.sm)
                            .disabled(isLoading)

                            Text("Al crear tu cuenta aceptas que tus datos son usados únicamente para conectar residuos con recolectores.")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, Sp.lg)
                        .padding(.top, Sp.xl)
                        .padding(.bottom, Sp.xxl)
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))

                        Text("Regresar")
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                    }
                    .foregroundColor(.nexoDeep)
                }
            }
        }
    }

    private func createAccount() {
        localError = nil
        auth.errorMessage = nil

        guard !nombre.isEmpty,
              !apellido.isEmpty,
              !email.isEmpty,
              !password.isEmpty else {
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
                nombre: nombre,
                apellido: apellido,
                email: email,
                telefono: telefono,
                edad: edad,
                password: password,
                avatarData: avatarData
            )

            isLoading = false
        }
    }

    private func signUpField(_ label: String, text: Binding<String>) -> some View {
        TextField(label, text: text)
            .font(.system(size: 15, design: .rounded))
            .padding(.horizontal, Sp.md)
            .frame(height: 48)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Rd.sm))
    }

    private func signUpSecureField(_ label: String, text: Binding<String>) -> some View {
        SecureField(label, text: text)
            .font(.system(size: 15, design: .rounded))
            .padding(.horizontal, Sp.md)
            .frame(height: 48)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Rd.sm))
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

#Preview {
    NavigationStack {
        SignUpView()
            .environmentObject(AuthService.shared)
    }
}
