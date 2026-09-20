import Foundation

enum WordDiff {
    static func changedWordCount(raw: String, polished: String) -> Int {
        let a = raw.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        let b = polished.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var dp = Array(0...b.count)
        for i in 1...a.count {
            var prev = dp[0]; dp[0] = i
            for j in 1...b.count {
                let temp = dp[j]
                dp[j] = a[i-1] == b[j-1] ? prev : min(prev, dp[j], dp[j-1]) + 1
                prev = temp
            }
        }
        return dp[b.count]
    }
}
