import Foundation

struct ExecutiveRecord: Codable {
    let id: ExecutiveId
    let name: ExecutiveName
    let bio: ExecutiveBio
    let terms: [ExecutiveTerm]

    var currentTerm: ExecutiveTerm? {
        let today = Date()
        return terms.last { term in
            guard let end = term.endDate else { return false }
            return end > today
        } ?? terms.last
    }

    var displayName: String {
        name.officialFull ?? {
            var parts = [name.first]
            if let middle = name.middle { parts.append(middle) }
            parts.append(name.last)
            return parts.joined(separator: " ")
        }()
    }
}

struct ExecutiveId: Codable {
    let bioguide: String?
    let govtrack: Int?
}

struct ExecutiveName: Codable {
    let first: String
    let last: String
    let officialFull: String?
    let middle: String?
    let nickname: String?

    enum CodingKeys: String, CodingKey {
        case first, last, middle, nickname
        case officialFull = "official_full"
    }
}

struct ExecutiveBio: Codable {
    let birthday: String?
    let gender: String?
}

struct ExecutiveTerm: Codable {
    let type: String
    let start: String
    let end: String
    let party: String?
    let how: String?

    var endDate: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: end)
    }

    var isPresident: Bool { type == "prez" }
    var isVicePresident: Bool { type == "viceprez" }
}
