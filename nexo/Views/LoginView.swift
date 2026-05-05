import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        ZStack(alignment: .top) {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {

                // MARK: Header blanco
                VStack(alignment: .leading, spacing: Sp.xs) {
                    Text("Bienvenido\nde vuelta ♻️")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundColor(.nexoDeep)
                    Text("Inicia sesión para continuar.")
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Sp.lg)
                .padding(.top, 72)
                .padding(.bottom, Sp.xl)

                // MARK: Bloque verde
                ZStack(alignment: .top) {

                    Color.nexoGreen
                        .clipShape(
                            RoundedCorner(radius: 32, corners: [.topLeft, .topRight])
                        )
                        .ignoresSafeArea(edges: .bottom)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: Sp.md) {

                            Spacer().frame(height: Sp.lg)

                            // Campos
                            loginField("Correo electrónico", text: $email)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)

                            loginSecureField("Contraseña", text: $password)

                            // Error
                            if let error = auth.errorMessage {
                                HStack(spacing: Sp.sm) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundColor(.white)
                                    Text(error)
                                        .font(.system(size: 13, design: .rounded))
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            // Botón
                            Button("Iniciar sesión") {
                                Task { await auth.signIn(email: email, password: password) }
                            }
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.nexoGreen)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.nexoDeep)
                            .clipShape(Capsule())
                            .padding(.top, Sp.sm)

                            // Link a SignUp
                            HStack(spacing: 4) {
                                Text("¿No tienes cuenta?")
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundColor(.white.opacity(0.8))
                                NavigationLink(destination: SignUpView()) {
                                    Text("Regístrate")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                        .underline()
                                }
                            }
                            .padding(.top, Sp.xs)
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

    // MARK: - Campos
    private func loginField(_ label: String, text: Binding<String>) -> some View {
        TextField(label, text: text)
            .font(.system(size: 15, design: .rounded))
            .padding(.horizontal, Sp.md)
            .frame(height: 48)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Rd.sm))
    }

    private func loginSecureField(_ label: String, text: Binding<String>) -> some View {
        SecureField(label, text: text)
            .font(.system(size: 15, design: .rounded))
            .padding(.horizontal, Sp.md)
            .frame(height: 48)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Rd.sm))
    }
}

#Preview {
    NavigationStack {
        LoginView()
            .environmentObject(AuthService.shared)
    }
}
