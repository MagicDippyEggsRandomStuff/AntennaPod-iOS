import XCTest
@testable import AntennaPodCore

final class ParsingUtilityTests: XCTestCase {
    func testRFC822Date() {
        let date = FeedDate.parse("Tue, 02 Jan 2024 10:00:00 +0000")
        XCTAssertNotNil(date)
        XCTAssertEqual(date.map { Int($0.timeIntervalSince1970) }, 1704189600)
    }

    func testISO8601Date() {
        let date = FeedDate.parse("2024-01-02T10:00:00Z")
        XCTAssertEqual(date.map { Int($0.timeIntervalSince1970) }, 1704189600)
    }

    func testDateWithSlashes() {
        XCTAssertNotNil(FeedDate.parse("02/01/2024 10:00:00 +0000"))
    }

    func testInvalidDate() {
        XCTAssertNil(FeedDate.parse("not a date"))
        XCTAssertNil(FeedDate.parse(nil))
    }

    func testDurationFormats() {
        XCTAssertEqual(DurationParser.seconds(from: "01:02:03"), 3723)
        XCTAssertEqual(DurationParser.seconds(from: "45:30"), 2730)
        XCTAssertEqual(DurationParser.seconds(from: "3600"), 3600)
        XCTAssertEqual(DurationParser.seconds(from: "12.5"), 12.5)
        XCTAssertEqual(DurationParser.seconds(from: "1h2m3s"), 3723)
        XCTAssertNil(DurationParser.seconds(from: ""))
        XCTAssertNil(DurationParser.seconds(from: nil))
    }

    func testDurationFormatting() {
        XCTAssertEqual(DurationParser.formatted(3723), "1:02:03")
        XCTAssertEqual(DurationParser.formatted(90), "1:30")
        XCTAssertEqual(DurationParser.formatted(-1), "--:--")
    }

    func testHTMLStripping() {
        let html = "<p>Hello <b>world</b> &amp; friends</p><p>Second&#39;s line</p>"
        XCTAssertEqual(HTMLText.plainText(from: html), "Hello world & friends\n\nSecond's line")
    }

    func testHTMLEntities() {
        XCTAssertEqual(HTMLText.decodeEntities(in: "a &lt; b &#x2014; c"), "a < b \u{2014} c")
    }
}
