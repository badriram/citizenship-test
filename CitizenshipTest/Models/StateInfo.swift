import Foundation

struct StateInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let capital: String
    let governor: String
    let senators: [String]
}
