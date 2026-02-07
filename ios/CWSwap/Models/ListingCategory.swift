import Foundation

enum ListingCategory: String, Codable, Hashable, CaseIterable, Identifiable, Sendable {
    case hfRadios = "hf_radios"
    case vhfUhfRadios = "vhf_uhf_radios"
    case hfAmplifiers = "hf_amplifiers"
    case vhfUhfAmplifiers = "vhf_uhf_amplifiers"
    case hfAntennas = "hf_antennas"
    case vhfUhfAntennas = "vhf_uhf_antennas"
    case towers
    case rotators
    case keys
    case testEquipment = "test_equipment"
    case computers
    case antiqueRadios = "antique_radios"
    case accessories
    case miscellaneous

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hfRadios: "HF Radios"
        case .vhfUhfRadios: "VHF/UHF Radios"
        case .hfAmplifiers: "HF Amplifiers"
        case .vhfUhfAmplifiers: "VHF/UHF Amplifiers"
        case .hfAntennas: "HF Antennas"
        case .vhfUhfAntennas: "VHF/UHF Antennas"
        case .towers: "Towers"
        case .rotators: "Rotators"
        case .keys: "Keys & Keyers"
        case .testEquipment: "Test Equipment"
        case .computers: "Computers"
        case .antiqueRadios: "Antique Radios"
        case .accessories: "Accessories"
        case .miscellaneous: "Miscellaneous"
        }
    }

    var sfSymbol: String {
        switch self {
        case .hfRadios: "radio"
        case .vhfUhfRadios: "antenna.radiowaves.left.and.right"
        case .hfAmplifiers: "bolt.fill"
        case .vhfUhfAmplifiers: "bolt.fill"
        case .hfAntennas: "antenna.radiowaves.left.and.right"
        case .vhfUhfAntennas: "antenna.radiowaves.left.and.right"
        case .towers: "building.2"
        case .rotators: "arrow.triangle.2.circlepath"
        case .keys: "pianokeys"
        case .testEquipment: "waveform"
        case .computers: "desktopcomputer"
        case .antiqueRadios: "clock.arrow.circlepath"
        case .accessories: "wrench.and.screwdriver"
        case .miscellaneous: "ellipsis.circle"
        }
    }
}
