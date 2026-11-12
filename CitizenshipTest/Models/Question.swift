import Foundation

enum StateAnswerKey: String, Codable {
    case senators
    case governor
    case capital
    case representative
}

struct Question: Identifiable, Hashable {
    let id: Int
    let category: QuestionCategory
    let text: String
    let answers: [String]
    let stateSpecific: StateAnswerKey?

    init(id: Int, category: QuestionCategory, text: String, answers: [String], stateSpecific: StateAnswerKey? = nil) {
        self.id = id
        self.category = category
        self.text = text
        self.answers = answers
        self.stateSpecific = stateSpecific
    }

    func answersForState(_ state: StateInfo?) -> [String] {
        guard let key = stateSpecific, let state = state else { return answers }
        switch key {
        case .senators: return state.senators
        case .governor: return [state.governor]
        case .capital: return [state.capital]
        case .representative: return ["Answers will vary — visit house.gov to find yours"]
        }
    }

    func answersForState(_ state: StateInfo?, legislators: LegislatorStore?, district: Int?) -> [String] {
        guard let key = stateSpecific, let state = state else { return answers }
        switch key {
        case .senators:
            if let legislators {
                let live = legislators.senatorsForState(state.id)
                if !live.isEmpty { return live }
            }
            return state.senators
        case .governor:
            return [legislators?.governorForState(state.id) ?? state.governor]
        case .capital:
            return [state.capital]
        case .representative:
            if let legislators, let district {
                if let rep = legislators.representativeForDistrict(state: state.id, district: district) {
                    return [rep]
                }
            }
            return ["Answers will vary — visit house.gov to find yours"]
        }
    }
}
