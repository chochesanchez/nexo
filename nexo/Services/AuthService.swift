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
    @Published var nombre: String?
    @Published var apellido: String?
    @Published var correo: String?
    @Published var telefono: String?
    @Published var signupCompleted = false

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
            struct EmailCheckParams: Encodable { let p_email: String }
            let alreadyExists: Bool = (try? await client
                .rpc("email_in_profiles", params: EmailCheckParams(p_email: email))
                .execute()
                .value) ?? false

            if alreadyExists {
                errorMessage = "Esta cuenta ya existe. Inicia sesión."
                return
            }

            let response = try await client.auth.signUp(email: email, password: password)
            let user = response.user

            guard response.session != nil else {
                errorMessage = "Email confirmation debe estar OFF en Supabase."
                return
            }

            var uploadedAvatarUrl: String? = nil
            if let data = avatarData {
                do {
                    uploadedAvatarUrl = try await StorageService.shared.uploadAvatar(data, userId: user.id)
                } catch {
                    print("[Auth] avatar upload failed:", error.localizedDescription)
                }
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

            try? await client.auth.signOut()
            isAuthenticated = false
            currentUserId = nil
            avatarURL = nil
            signupCompleted = true
        } catch {
            let desc = error.localizedDescription.lowercased()
            if desc.contains("already registered") || desc.contains("user_already_exists") {
                errorMessage = "Esta cuenta ya existe. Inicia sesión."
            } else if desc.contains("weak_password") {
                errorMessage = "Contraseña muy débil. Usa al menos 8 caracteres."
            } else if desc.contains("missing email") || desc.contains("validation_failed") {
                errorMessage = "Completa correo y contraseña."
            } else if desc.contains("rate") || desc.contains("limit") {
                errorMessage = "Demasiados intentos. Espera unos minutos."
            } else {
                errorMessage = "Error al registrarse: \(error.localizedDescription)"
            }
            print("[Auth] signUp:", error)
        }
    }

    func signOut() async {
        do {
            try await client.auth.signOut()
            isAuthenticated = false
            currentUserId = nil
            avatarURL = nil
            nombre = nil
            apellido = nil
            correo = nil
            telefono = nil
        } catch {
            print("[Auth] signOut:", error)
        }
    }

    func loadSession() async {
        if let session = client.auth.currentSession, !session.isExpired {
            isAuthenticated = true
            currentUserId = client.auth.currentUser?.id
            await fetchProfile()
        } else {
            isAuthenticated = false
            currentUserId = nil
            avatarURL = nil
            try? await client.auth.signOut()
        }
    }

    private func fetchProfile() async {
        guard let id = currentUserId else { return }
        struct P: Decodable {
            let nombre: String?
            let apellido: String?
            let correo: String?
            let telefono: String?
            let avatarUrl: String?
            enum CodingKeys: String, CodingKey {
                case nombre, apellido, correo, telefono
                case avatarUrl = "avatar_url"
            }
        }
        do {
            let rows: [P] = try await client
                .from("profiles")
                .select("nombre, apellido, correo, telefono, avatar_url")
                .eq("user_id", value: id.uuidString)
                .limit(1)
                .execute()
                .value
            if let p = rows.first {
                nombre    = p.nombre
                apellido  = p.apellido
                correo    = p.correo
                telefono  = p.telefono
                avatarURL = p.avatarUrl
            }
        } catch {
            print("[Auth] fetchProfile:", error)
        }
    }
}
