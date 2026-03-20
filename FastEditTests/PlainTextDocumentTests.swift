import Testing
import Foundation
@testable import FastEdit

struct PlainTextDocumentTests {
    // MARK: - autosavesInPlace

    @Test func autosavesInPlaceIsFalse() {
        #expect(PlainTextDocument.autosavesInPlace == false)
    }

    // MARK: - UTF-8 round-trip

    @Test func readAndDataRoundTrip() throws {
        let doc = PlainTextDocument()
        let original = "Hello, world!"
        let data = original.data(using: .utf8)!

        try doc.read(from: data, ofType: "public.plain-text")
        let output = try doc.data(ofType: "public.plain-text")

        #expect(output == data)
        #expect(doc.text == original)
    }

    @Test func roundTripWithJapaneseText() throws {
        let doc = PlainTextDocument()
        let original = "日本語テスト 🍣"
        let data = original.data(using: .utf8)!

        try doc.read(from: data, ofType: "public.plain-text")
        let output = try doc.data(ofType: "public.plain-text")

        #expect(String(data: output, encoding: .utf8) == original)
    }

    @Test func roundTripWithEmptyText() throws {
        let doc = PlainTextDocument()
        let data = "".data(using: .utf8)!

        try doc.read(from: data, ofType: "public.plain-text")
        let output = try doc.data(ofType: "public.plain-text")

        #expect(output == data)
        #expect(doc.text == "")
    }

    @Test func roundTripPreservesNewlines() throws {
        let doc = PlainTextDocument()
        let original = "line1\nline2\rline3\r\nline4"
        let data = original.data(using: .utf8)!

        try doc.read(from: data, ofType: "public.plain-text")
        #expect(doc.text == original)
    }

    // MARK: - Invalid data

    @Test func readNonUTF8DataThrows() {
        let doc = PlainTextDocument()
        // Invalid UTF-8 sequence
        let invalidData = Data([0xFF, 0xFE, 0x80, 0x81])

        #expect(throws: (any Error).self) {
            try doc.read(from: invalidData, ofType: "public.plain-text")
        }
    }
}
