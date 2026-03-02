import Foundation

enum QuestionCategory: String, CaseIterable, Identifiable, Codable {
    case govPrinciples = "Gov-Principles"
    case govSystem = "Gov-System"
    case rights = "Rights"
    case historyColonial = "History-Colonial"
    case history1800s = "History-1800s"
    case historyModern = "History-Modern"
    case historyTribes = "History-Tribes"
    case historyInnovation = "History-Innovation"
    case symbols = "Symbols"
    case holidays = "Holidays"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .govPrinciples: return "Principles of Government"
        case .govSystem: return "System of Government"
        case .rights: return "Rights & Responsibilities"
        case .historyColonial: return "Colonial Period"
        case .history1800s: return "1800s History"
        case .historyModern: return "Modern History"
        case .historyTribes: return "American Indian Tribes"
        case .historyInnovation: return "American Innovation"
        case .symbols: return "Symbols"
        case .holidays: return "Holidays"
        }
    }

    var icon: String {
        switch self {
        case .govPrinciples: return "building.columns"
        case .govSystem: return "gearshape.2"
        case .rights: return "hand.raised"
        case .historyColonial: return "scroll"
        case .history1800s: return "book.closed"
        case .historyModern: return "globe.americas"
        case .historyTribes: return "leaf"
        case .historyInnovation: return "lightbulb"
        case .symbols: return "flag"
        case .holidays: return "calendar"
        }
    }
}
