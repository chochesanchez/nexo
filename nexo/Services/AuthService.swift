import Foundation
import Supabase
import Combine

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published var isAuthenticated = false
    @Published var errorMessage: String?
    @Published var currentUserId: UUID?
    @Published var avatarURL: String?

    private let client = SupabaseClientProvider.shared.client

    private init() {}

    func signIn(email: String, password: String) async {
        errorMessage = nil
        do {
            try await client.auth.signIn(email: email, password: password)
            currentUserId = client.auth.currentUser?.id
            isAuthenticated = true
            await fetchProfile()
        } catch {
            errorMessage = "Correo o contraseña incorrectos."
            print("[Auth] signIn:", error)
        }
    }

    func signUp(nombre: String, apellido: String, email: String, telefono: String, edad: Int, password: String, avatarData: Data? = nil) async {
        errorMessage = nil
        do {
            let response = try await client.auth.signUp(
                email: email,
                password: password,
                data: [
                    "nombre"   : .string(nombre),
                    "apellido" : .string(apellido),
                    "telefono" : .string(telefono),
                    "edad"     : .integer(edad)
                ]
            )
            let user = response.user
            currentUserId = user.id

            if let data = avatarData {
                if let uploaded = try? await StorageService.shared.uploadAvatar(data, userId: user.id) {
                    _ = try? await client
                        .from("profiles")
                        .update(["avatar_url": uploaded])
                        .eq("user_id", value: user.id.uuidString)
                        .execute()
                    avatarURL = uploaded
                }
            }

            isAuthenticated = response.session != nil
        } catch {
            errorMessage = "Error al registrarse. Intenta con otro correo."
            print("[Auth] signUp:", error)
        }
    }

    func signOut() async {
        do {
            try await client.auth.signOut()
            isAuthenticated = false
            currentUserId = nil
            avatarURL = nil
        } catch {
            print("[Auth] signOut:", error)
        }
    }

    func loadSession() async {
        isAuthenticated = client.auth.currentSession != nil
        if isAuthenticated {
            currentUserId = client.auth.currentUser?.id
            await fetchProfile()
        }
    }

    private func fetchProfile() async {
        guard let id = currentUserId else { return }
        struct P: Decodable {
            let avatarUrl: String?
            enum CodingKeys: String, CodingKey { case avatarUrl = "avatar_url" }
        }
        do {
            let p: P = try await client
                .from("profiles")
                .select("avatar_url")
                .eq("user_id", value: id.uuidString)
                .single()
                .execute()
                .value
            avatarURL = p.avatarUrl
        } catch {
            print("[Auth] fetchProfile:", error)
        }
    }
}
