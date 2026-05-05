//
//  nexoApp.swift
//  nexo
//
//  Created by José Manuel Sánchez Pérez on 04/05/26.
//

import SwiftUI
import SwiftData

@main
struct nexoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    if url.host == "scan"     { NotificationCenter.default.post(name: .nexoOpenScanner,   object: nil) }
                    if url.host == "historial"{ NotificationCenter.default.post(name: .nexoOpenHistorial, object: nil) }
                }
        }
        .modelContainer(for: FichaRegistro.self)
    }
}
