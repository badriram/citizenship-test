import Foundation

struct LegislatorRecord: Codable {
    let id: LegislatorId
    let name: LegislatorName
    let bio: LegislatorBio
    let terms: [LegislatorTerm]

    var currentTerm: LegislatorTerm? {
        let today = Date()
        return terms.last { term in
            guard let end = term.endDate else { return false }
            return end > today
        } ?? terms.last
    }

    var displayName: String {
        name.officialFull ?? "\(name.first) \(name.last)"
    }
}

struct LegislatorId: Codable {
    let bioguide: String
}

struct LegislatorName: Codable {
    let first: String
    let last: String
    let officialFull: String?
    let middle: String?
    let suffix: String?
    let nickname: String?

    enum CodingKeys: String, CodingKey {
        case first, last, middle, suffix, nickname
        case officialFull = "official_full"
    }
}

struct LegislatorBio: Codable {
    let birthday: String?
    let gender: String?
}

struct LegislatorTerm: Codable {
    let type: String
    let start: String
    let end: String
    let state: String?
    let district: Int?
    let party: String?
    let senateClass: Int?
    let stateRank: String?

    enum CodingKeys: String, CodingKey {
        case type, start, end, state, district, party
        case senateClass = "class"
        case stateRank = "state_rank"
    }

    var endDate: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: end)
    }

    var isSenator: Bool { type == "sen" }
    var isRepresentative: Bool { type == "rep" }
}
