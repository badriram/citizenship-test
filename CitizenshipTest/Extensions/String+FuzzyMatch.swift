import Foundation

extension String {
    func normalized() -> String {
        self.lowercased()
            .replacingOccurrences(of: "[().,]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    func words() -> [String] {
        normalized().components(separatedBy: " ").filter { $0.count > 1 }
    }

    func levenshteinDistance(to target: String) -> Int {
        let s = Array(self)
        let t = Array(target)
        let m = s.count
        let n = t.count

        if m == 0 { return n }
        if n == 0 { return m }

        var matrix = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)

        for i in 0...m { matrix[i][0] = i }
        for j in 0...n { matrix[0][j] = j }

        for i in 1...m {
            for j in 1...n {
                let cost = s[i - 1] == t[j - 1] ? 0 : 1
                matrix[i][j] = Swift.min(
                    matrix[i - 1][j] + 1,
                    matrix[i][j - 1] + 1,
                    matrix[i - 1][j - 1] + cost
                )
            }
        }
        return matrix[m][n]
    }

    func extractCapitalizedNames() -> [String] {
        let pattern = "\\b[A-Z][a-z]+\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(startIndex..., in: self)
        return regex.matches(in: self, range: range).compactMap { match in
            guard let r = Range(match.range, in: self) else { return nil }
            return String(self[r])
        }
    }
}
