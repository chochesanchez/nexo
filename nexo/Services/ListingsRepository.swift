import Foundation
import Combine
import Supabase

@MainActor
final class ListingsRepository: ObservableObject {

    @Published var listings  : [Listing]      = []
    @Published var history   : [ScanRecord]   = []
    @Published var centros   : [CentroAcopio] = []
    @Published var isLoading = false
    @Published var lastError : String?

    private let client = SupabaseClientProvider.shared.client

    func fetchAvailable() async {
        isLoading = true
        defer { isLoading = false }
        do {
            listings = try await client
                .from("listings")
                .select()
                .eq("status", value: "available")
                .order("created_at", ascending: false)
                .execute()
                .value
        } catch {
            lastError = "No pudimos cargar las fichas disponibles."
            print("[Supabase] fetchAvailable error:", error)
        }
    }

    func publish(_ new: NewListing) async -> Bool {
        do {
            try await client
                .from("listings")
                .insert(new)
                .execute()
            await fetchAvailable()
            return true
        } catch {
            lastError = "No pudimos publicar la ficha."
            print("[Supabase] publish error:", error)
            return false
        }
    }

    func markClaimed(_ listing: Listing) async {
        do {
            try await client
                .from("listings")
                .update(["status": "claimed"])
                .eq("id", value: listing.id.uuidString)
                .execute()
            listings.removeAll { $0.id == listing.id }
        } catch {
            lastError = "No pudimos confirmar la recolección."
            print("[Supabase] markClaimed error:", error)
        }
    }

    func fetchHistory() async {
        guard let userId = client.auth.currentUser?.id else { return }
        do {
            history = try await client
                .from("scan_history")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value
        } catch {
            print("[Supabase] fetchHistory error:", error)
        }
    }

    func insertScanRecord(_ record: NewScanRecord) async {
        do {
            try await client
                .from("scan_history")
                .insert(record)
                .execute()
        } catch {
            print("[Supabase] insertScanRecord error:", error)
        }
    }

    func fetchCentros() async {
        do {
            centros = try await client
                .from("centros_reciclaje")
                .select()
                .execute()
                .value
        } catch {
            print("[Supabase] fetchCentros error:", error)
        }
    }
}
