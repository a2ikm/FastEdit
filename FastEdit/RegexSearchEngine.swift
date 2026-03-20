import Foundation

struct SearchOptions {
    var isRegex: Bool = true
    var isCaseSensitive: Bool = true
}

struct RegexSearchEngine {
    private func makeRegex(pattern: String, options: SearchOptions) throws -> NSRegularExpression {
        var regexOptions: NSRegularExpression.Options = []
        if !options.isCaseSensitive {
            regexOptions.insert(.caseInsensitive)
        }
        if !options.isRegex {
            regexOptions.insert(.ignoreMetacharacters)
        }
        return try NSRegularExpression(pattern: pattern, options: regexOptions)
    }

    func findMatches(
        pattern: String,
        in text: String,
        range: NSRange,
        options: SearchOptions
    ) throws -> [NSTextCheckingResult] {
        guard !pattern.isEmpty else { return [] }
        let regex = try makeRegex(pattern: pattern, options: options)
        return regex.matches(in: text, range: range)
    }

    func replacementString(
        for result: NSTextCheckingResult,
        in text: String,
        pattern: String,
        template: String,
        options: SearchOptions
    ) throws -> String {
        let regex = try makeRegex(pattern: pattern, options: options)
        return regex.replacementString(for: result, in: text, offset: 0, template: template)
    }
}
