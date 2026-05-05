import Foundation
import Supabase

@MainActor
final class StorageService {
    static let shared = StorageService()
    private let client = SupabaseClientProvider.shared.client
    private init() {}

    func uploadAvatar(_ data: Data, userId: UUID) async throws -> String {
        let path = "\(userId.uuidString)/avatar.jpg"
        do {
            try await client.storage.from("avatars").upload(
                path,
                data: data,
                options: FileOptions(contentType: "image/jpeg", upsert: true)
            )
            let url = try client.storage.from("avatars").getPublicURL(path: path)
            return url.absoluteString
        } catch {
            print("[Storage] uploadAvatar FAILED — bucket=avatars path=\(path) error=\(error.localizedDescription)")
            throw error
        }
    }

    func uploadScanImage(_ data: Data, userId: UUID) async throws -> String {
        let path = "\(userId.uuidString)/\(UUID().uuidString).jpg"
        do {
            try await client.storage.from("scan-images").upload(
                path,
                data: data,
                options: FileOptions(contentType: "image/jpeg")
            )
            let url = try client.storage.from("scan-images").getPublicURL(path: path)
            return url.absoluteString
        } catch {
            print("[Storage] uploadScanImage FAILED — bucket=scan-images path=\(path) error=\(error.localizedDescription)")
            throw error
        }
    }
}
