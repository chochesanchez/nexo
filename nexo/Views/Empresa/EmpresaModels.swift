//
//  EmpresaModels.swift
//  nexo
//
//  Created by Grecia Saucedo on 05/05/26.
//

import Foundation

enum FrecuenciaGeneracion: String, CaseIterable, Codable {
    case diaria     = "Diaria"
    case semanal    = "Semanal"
    case quincenal  = "Quincenal"
    case mensual    = "Mensual"
}

enum TipoGenerador: String, CaseIterable, Codable {
    case empresa     = "Empresa"
    case restaurante = "Restaurante"
    case hospital    = "Hospital / Clínica"
    case manufactura = "Manufactura"
    case oficina     = "Oficina"
    case otro        = "Otro"

    var icon: String {
        switch self {
        case .empresa:     return "building.2.fill"
        case .restaurante: return "fork.knife"
        case .hospital:    return "cross.fill"
        case .manufactura: return "gearshape.2.fill"
        case .oficina:     return "desktopcomputer"
        case .otro:        return "square.grid.2x2.fill"
        }
    }
}

