//
//  ContentView.swift
//  nexo
//
//  Created by José Manuel Sánchez Pérez on 04/05/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var repo = ListingsRepository()

    var body: some View {
        NavigationStack {
            List(repo.listings) { listing in
                VStack(alignment: .leading) {
                    Text(listing.material).font(.headline)
                    if let q = listing.quantityLabel {
                        Text(q).foregroundStyle(.secondary)
                    }
                }
            }
            .overlay { if repo.isLoading { ProgressView() } }
            .navigationTitle("NEXO")
            .task { await repo.fetchAvailable() }
            .alert("Error", isPresented: .constant(repo.lastError != nil)) {
                Button("OK") { repo.lastError = nil }
            } message: {
                Text(repo.lastError ?? "")
            }
        }
    }
}
