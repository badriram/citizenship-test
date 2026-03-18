import Foundation

@Observable
final class LegislatorStore {
    private(set) var senators: [String: [String]] = [:]       // state code → [names]
    private(set) var representatives: [String: String] = [:]   // "CA-12" → name
    private(set) var president: String?
    private(set) var vicePresident: String?
    private(set) var lastRefreshed: Date?
    private(set) var isLoading = false
    private(set) var loadError: String?

    private static let legislatorsURL = URL(string: "https://unitedstates.github.io/congress-legislators/legislators-current.json")!
    private static let executiveURL = URL(string: "https://unitedstates.github.io/congress-legislators/executive.json")!
    private static let staleDays = 14

    // MARK: - Public API

    func loadBundled() {
        if let legURL = Bundle.main.url(forResource: "legislators-current", withExtension: "json") {
            loadLegislators(from: legURL)
        }
        if let exURL = Bundle.main.url(forResource: "executive", withExtension: "json") {
            loadExecutive(from: exURL)
        }
    }

    @MainActor
    func refreshIfNeeded() async {
        guard shouldRefresh else { return }
        isLoading = true
        loadError = nil
        defer { isLoading = false }

        do {
            try await fetchAndCache(from: Self.legislatorsURL, cacheFileName: "legislators-current.json")
            try await fetchAndCache(from: Self.executiveURL, cacheFileName: "executive.json")

            if let legFile = cachedFileURL(named: "legislators-current.json") {
                loadLegislators(from: legFile)
            }
            if let exFile = cachedFileURL(named: "executive.json") {
                loadExecutive(from: exFile)
            }

            lastRefreshed = Date()
            UserDefaults.standard.set(Date(), forKey: "legislatorLastRefreshed")
        } catch {
            loadError = error.localizedDescription
            // Try loading from cache as fallback
            if let legFile = cachedFileURL(named: "legislators-current.json") {
                loadLegislators(from: legFile)
            }
            if let exFile = cachedFileURL(named: "executive.json") {
                loadExecutive(from: exFile)
            }
        }
    }

    func senatorsForState(_ stateCode: String) -> [String] {
        if let live = senators[stateCode], !live.isEmpty {
            return live
        }
        // Fallback to StatesData
        return statesData.first { $0.id == stateCode }?.senators ?? []
    }

    func representativeForDistrict(state: String, district: Int) -> String? {
        let key = "\(state)-\(district)"
        return representatives[key]
    }

    func allRepresentativesForState(_ state: String) -> [String] {
        representatives
            .filter { $0.key.hasPrefix("\(state)-") }
            .sorted { $0.key < $1.key }
            .map { $0.value }
    }

    // MARK: - Private

    private var shouldRefresh: Bool {
        guard let last = UserDefaults.standard.object(forKey: "legislatorLastRefreshed") as? Date else {
            return true
        }
        let daysSince = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? Int.max
        return daysSince >= Self.staleDays
    }

    private func loadLegislators(from url: URL) {
        guard let data = try? Data(contentsOf: url) else { return }
        guard let records = try? JSONDecoder().decode([LegislatorRecord].self, from: data) else { return }

        var newSenators: [String: [String]] = [:]
        var newReps: [String: String] = [:]

        for record in records {
            guard let term = record.currentTerm, let state = term.state else { continue }

            if term.isSenator {
                newSenators[state, default: []].append(record.displayName)
            } else if term.isRepresentative {
                let district = term.district ?? 0
                let key = "\(state)-\(district)"
                newReps[key] = record.displayName
            }
        }

        self.senators = newSenators
        self.representatives = newReps
    }

    private func loadExecutive(from url: URL) {
        guard let data = try? Data(contentsOf: url) else { return }
        guard let records = try? JSONDecoder().decode([ExecutiveRecord].self, from: data) else { return }

        let today = Date()
        for record in records {
            guard let term = record.currentTerm, let endDate = term.endDate, endDate > today else { continue }
            if term.isPresident {
                self.president = record.displayName
            } else if term.isVicePresident {
                self.vicePresident = record.displayName
            }
        }
    }

    private nonisolated func fetchAndCache(from remoteURL: URL, cacheFileName: String) async throws {
        let (data, response) = try await URLSession.shared.data(from: remoteURL)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let cacheDir = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let fileURL = cacheDir.appendingPathComponent(cacheFileName)
        try data.write(to: fileURL, options: .atomic)
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: fileURL.path
        )
    }

    private func cachedFileURL(named name: String) -> URL? {
        guard let cacheDir = try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false) else {
            return nil
        }
        let fileURL = cacheDir.appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
    }
}
