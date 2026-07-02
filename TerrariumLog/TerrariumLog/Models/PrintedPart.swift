import Foundation
import SwiftData

@Model
final class PrintedPart {
    var name: String
    var material: PrintMaterial
    var technology: PrintTechnology
    var usageNotes: String
    var printedDate: Date?
    var notes: String

    var terrarium: Terrarium?

    init(
        name: String,
        material: PrintMaterial,
        technology: PrintTechnology,
        usageNotes: String = "",
        printedDate: Date? = nil,
        notes: String = "",
        terrarium: Terrarium? = nil
    ) {
        self.name = name
        self.material = material
        self.technology = technology
        self.usageNotes = usageNotes
        self.printedDate = printedDate
        self.notes = notes
        self.terrarium = terrarium
    }
}

enum PrintMaterial: String, Codable, CaseIterable, Sendable {
    case petg
    case pa12
    case pla
    case plc

    var displayName: String {
        switch self {
        case .petg: return "PETG"
        case .pa12: return "PA12"
        case .pla: return "PLA"
        case .plc: return "PLC"
        }
    }
}

enum PrintTechnology: String, Codable, CaseIterable, Sendable {
    case fdm
    case mjf
    case sls
    case sla

    var displayName: String {
        switch self {
        case .fdm: return "FDM"
        case .mjf: return "MJF"
        case .sls: return "SLS"
        case .sla: return "SLA"
        }
    }
}
