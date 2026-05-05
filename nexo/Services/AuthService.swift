import Foundation
import Supabase
import Combine

private struct UpsertProfileParams: Encodable {
    let nombre: String
    let apellido: String
    let telefono: String
    let correo: String
    let edad: Int
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case nombre   = "p_nombre"
        case apellido = "p_apellido"
        case telefono = "p_telefono"
        case correo   = "p_correo"
        case edad     = "p_edad"
        case avatarUrl = "p_avatar_url"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(nombre,   forKey: .nombre)
        try c.encode(apellido, forKey: .apellido)
        try c.encode(telefono, forKey: .telefono)
        try c.encode(correo,   forKey: .correo)
        try c.encode(edad,     forKey: .edad)
        if let url = avatarUrl {
            try c.encode(url, forKey: .avatarUrl)
        } else {
            try c.encodeNil(forKey: .avatarUrl)
        }
    }
}

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
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Ingresa correo y contraseña."
            return
        }
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
            let response = try await client.auth.signUp(email: email, password: password)
            let user = response.user
            currentUserId = user.id

            guard response.session != nil else {
                errorMessage = "Email confirmation debe estar OFF en Supabase."
                return
            }

            var uploadedAvatarUrl: String? = nil
            if let data = avatarData {
                uploadedAvatarUrl = try? await StorageService.shared.uploadAvatar(data, userId: user.id)
            }

            let params = UpsertProfileParams(
                nombre   : nombre,
                apellido : apellido,
                telefono : telefono,
                correo   : email,
                edad     : edad,
                avatarUrl: uploadedAvatarUrl
            )

            try await client
                .rpc("upsert_my_profile", params: params)
                .execute()

            avatarURL = uploadedAvatarUrl
            isAuthenticated = true
        } catch {
            errorMessage = "Error: \(error.localizedDescription)"
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
