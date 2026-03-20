import Testing
import Foundation
@testable import FastEdit

struct RegexSearchEngineTests {
    let engine = RegexSearchEngine()

    private func fullRange(of text: String) -> NSRange {
        NSRange(location: 0, length: (text as NSString).length)
    }

    // MARK: - Empty pattern

    @Test func emptyPatternReturnsNoMatches() throws {
        let text = "hello world"
        let matches = try engine.findMatches(
            pattern: "",
            in: text,
            range: fullRange(of: text),
            options: SearchOptions()
        )
        #expect(matches.isEmpty)
    }

    // MARK: - Literal (non-regex) search

    @Test func literalSearch() throws {
        let text = "foo bar foo"
        let matches = try engine.findMatches(
            pattern: "foo",
            in: text,
            range: fullRange(of: text),
            options: SearchOptions(isRegex: false, isCaseSensitive: true)
        )
        #expect(matches.count == 2)
        #expect(matches[0].range == NSRange(location: 0, length: 3))
        #expect(matches[1].range == NSRange(location: 8, length: 3))
    }

    @Test func literalSearchDoesNotInterpretMetacharacters() throws {
        let text = "a.b acb"
        let matches = try engine.findMatches(
            pattern: "a.b",
            in: text,
            range: fullRange(of: text),
            options: SearchOptions(isRegex: false, isCaseSensitive: true)
        )
        // "a.b" is literal, should only match "a.b" not "acb"
        #expect(matches.count == 1)
        #expect(matches[0].range == NSRange(location: 0, length: 3))
    }

    // MARK: - Regex search

    @Test func regexSearch() throws {
        let text = "a.b acb aXb"
        let matches = try engine.findMatches(
            pattern: "a.b",
            in: text,
            range: fullRange(of: text),
            options: SearchOptions(isRegex: true, isCaseSensitive: true)
        )
        // Regex "a.b" matches "a.b", "acb", "aXb"
        #expect(matches.count == 3)
    }

    @Test func regexSearchWithGroups() throws {
        let text = "2026-03-21"
        let matches = try engine.findMatches(
            pattern: "(\\d{4})-(\\d{2})-(\\d{2})",
            in: text,
            range: fullRange(of: text),
            options: SearchOptions(isRegex: true, isCaseSensitive: true)
        )
        #expect(matches.count == 1)
        #expect(matches[0].numberOfRanges == 4) // full match + 3 groups
    }

    @Test func invalidRegexThrows() {
        let text = "hello"
        #expect(throws: (any Error).self) {
            try engine.findMatches(
                pattern: "[invalid",
                in: text,
                range: fullRange(of: text),
                options: SearchOptions(isRegex: true, isCaseSensitive: true)
            )
        }
    }

    // MARK: - Case sensitivity

    @Test func caseSensitiveSearch() throws {
        let text = "Hello hello HELLO"
        let matches = try engine.findMatches(
            pattern: "hello",
            in: text,
            range: fullRange(of: text),
            options: SearchOptions(isRegex: false, isCaseSensitive: true)
        )
        #expect(matches.count == 1)
        #expect(matches[0].range == NSRange(location: 6, length: 5))
    }

    @Test func caseInsensitiveSearch() throws {
        let text = "Hello hello HELLO"
        let matches = try engine.findMatches(
            pattern: "hello",
            in: text,
            range: fullRange(of: text),
            options: SearchOptions(isRegex: false, isCaseSensitive: false)
        )
        #expect(matches.count == 3)
    }

    // MARK: - Search within range

    @Test func searchWithinSubrange() throws {
        let text = "foo bar foo baz foo"
        // Search only in "bar foo baz" (4..<15)
        let matches = try engine.findMatches(
            pattern: "foo",
            in: text,
            range: NSRange(location: 4, length: 11),
            options: SearchOptions(isRegex: false, isCaseSensitive: true)
        )
        #expect(matches.count == 1)
        #expect(matches[0].range == NSRange(location: 8, length: 3))
    }

    // MARK: - Japanese text

    @Test func searchJapaneseText() throws {
        let text = "東京は日本の首都です"
        let matches = try engine.findMatches(
            pattern: "日本",
            in: text,
            range: fullRange(of: text),
            options: SearchOptions(isRegex: false, isCaseSensitive: true)
        )
        #expect(matches.count == 1)
    }

    // MARK: - Replacement

    @Test func literalReplacement() throws {
        let text = "hello world"
        let matches = try engine.findMatches(
            pattern: "world",
            in: text,
            range: fullRange(of: text),
            options: SearchOptions(isRegex: false, isCaseSensitive: true)
        )
        let replacement = try engine.replacementString(
            for: matches[0],
            in: text,
            pattern: "world",
            template: "Swift",
            options: SearchOptions(isRegex: false, isCaseSensitive: true)
        )
        #expect(replacement == "Swift")
    }

    @Test func regexReplacementWithCaptureGroups() throws {
        let text = "2026-03-21"
        let matches = try engine.findMatches(
            pattern: "(\\d{4})-(\\d{2})-(\\d{2})",
            in: text,
            range: fullRange(of: text),
            options: SearchOptions(isRegex: true, isCaseSensitive: true)
        )
        let replacement = try engine.replacementString(
            for: matches[0],
            in: text,
            pattern: "(\\d{4})-(\\d{2})-(\\d{2})",
            template: "$2/$3/$1",
            options: SearchOptions(isRegex: true, isCaseSensitive: true)
        )
        #expect(replacement == "03/21/2026")
    }
}
