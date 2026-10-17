import XCTest
@testable import FeniceCore

final class FormatTests: XCTestCase {
    func testEuros() {
        XCTAssertEqual(Format.euros(0), "€ 0,00")
        XCTAssertEqual(Format.euros(2000), "€ 20,00")
        XCTAssertEqual(Format.euros(-3050), "-€ 30,50")
        XCTAssertEqual(Format.euros(123_456), "€ 1.234,56")
        XCTAssertEqual(Format.euros(100_000_005), "€ 1.000.000,05")
    }

    func testParseEuros() {
        XCTAssertEqual(Format.parseEuros("20"), 2000)
        XCTAssertEqual(Format.parseEuros("20,5"), 2050)
        XCTAssertEqual(Format.parseEuros("€ 1.200,00"), 120_000)
        XCTAssertEqual(Format.parseEuros("-5"), -500)
        XCTAssertEqual(Format.parseEuros("12.30"), 1230)
        XCTAssertNil(Format.parseEuros(""))
        XCTAssertNil(Format.parseEuros("dieci"))
    }

    func testDuration() {
        XCTAssertEqual(Format.duration(30), "30 min")
        XCTAssertEqual(Format.duration(60), "1 h")
        XCTAssertEqual(Format.duration(90), "1 h 30")
        XCTAssertEqual(Format.duration(120), "2 h")
    }

    func testClock() {
        XCTAssertEqual(Format.clock(minutes: 18 * 60 + 30), "18:30")
        XCTAssertEqual(Format.clock(minutes: 7 * 60), "07:00")
    }
}
