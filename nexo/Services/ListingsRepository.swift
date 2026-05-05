// ListingsRepository.swift
// Agrega markClaimed() para que el Modo Recolector pueda
// confirmar la recolección y actualizar el status en Supabase.

import Foundation
import Combine
import Supabase

@MainActor
final class ListingsRepository: ObservableObject {

    @Published var listings  : [Listing] = []
    @Published var isLoading = false
    @Published var lastError : String?

    private let client = SupabaseClientProvider.shared.client

    // MARK: - Fetch

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

    // MARK: - Publicar nueva ficha (Modo Hogar)

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

    // MARK: - Confirmar recolección (Modo Recolector)

    func markClaimed(_ listing: Listing) async {
        do {
            try await client
                .from("listings")
                .update(["status": "claimed"])
                .eq("id", value: listing.id.uuidString)
                .execute()
            // Remover localmente sin re-fetch completo
            listings.removeAll { $0.id == listing.id }
        } catch {
            lastError = "No pudimos confirmar la recolección."
            print("[Supabase] markClaimed error:", error)
        }
    }
}
