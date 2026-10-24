import XCTest
@testable import FeniceCore

final class BookingTests: XCTestCase {
    var clock: TestClock!
    var store: FeniceStore!
    var tutor: User!
    var student: User!
    var math: Int!

    override func setUpWithError() throws {
        clock = TestClock(date(2026, 10, 12, 10))
        store = try makeStore(clock: clock)
        tutor = try store.makeTestTutor(teaching: ["Matematica"])
        student = try store.registerStudent(firstName: "Marco", lastName: "Rossi", email: "marco@test.it", password: "password1")
        math = store.subjectId(named: "Matematica")
        try store.addAvailability(tutorId: tutor.id, start: date(2026, 10, 14, 15), end: date(2026, 10, 14, 19))
    }

    private func book(_ hour: Int, _ minute: Int = 0, duration: Int = 60, note: String = "") throws -> Booking {
        try store.bookLesson(
            studentId: student.id, tutorId: tutor.id, subjectId: math,
            start: date(2026, 10, 14, hour, minute), durationMinutes: duration,
            canAdvance: false, note: note
        )
    }

    func testPriceUsesGlobalRateOrSubjectRate() throws {
        XCTAssertEqual(store.price(subjectId: math, durationMinutes: 60), 2000)
        XCTAssertEqual(store.price(subjectId: math, durationMinutes: 90), 3000)
        let booking = try book(15, duration: 120)
        XCTAssertEqual(booking.priceCents, 4000)
        XCTAssertEqual(booking.end, date(2026, 10, 14, 17))
    }

    func testBookedSlotDisappears() throws {
        try book(16)
        let starts = store.freeSlots(tutorId: tutor.id, studentId: student.id, durationMinutes: 60).map(\.start)
        XCTAssertEqual(starts, [date(2026, 10, 14, 15), date(2026, 10, 14, 17), date(2026, 10, 14, 17, 30), date(2026, 10, 14, 18)])
        XCTAssertThrowsError(try book(16, 30))
    }

    func testStudentCannotDoubleBookWithAnotherTutor() throws {
        let other = try store.makeTestTutor(email: "altro@test.it", teaching: ["Matematica"])
        try store.addAvailability(tutorId: other.id, start: date(2026, 10, 14, 15), end: date(2026, 10, 14, 19))
        try book(15)
        let starts = store.freeSlots(tutorId: other.id, studentId: student.id, durationMinutes: 60).map(\.start)
        XCTAssertFalse(starts.contains(date(2026, 10, 14, 15)))
        XCTAssertFalse(starts.contains(date(2026, 10, 14, 15, 30)))
        XCTAssertTrue(starts.contains(date(2026, 10, 14, 16)))
    }

    func testValidation() throws {
        XCTAssertThrowsError(try book(15, duration: 45))
        XCTAssertThrowsError(try book(15, 15))
        XCTAssertThrowsError(try book(15, note: String(repeating: "a", count: 301)))
        let physics = store.subjectId(named: "Fisica")
        XCTAssertThrowsError(try store.bookLesson(
            studentId: student.id, tutorId: tutor.id, subjectId: physics,
            start: date(2026, 10, 14, 15), durationMinutes: 60, canAdvance: false, note: ""
        ))
    }

    func testBookingNotifiesBoth() throws {
        try book(15)
        XCTAssertTrue(store.db.notifications.contains { $0.userId == tutor.id })
        XCTAssertTrue(store.db.notifications.contains { $0.userId == student.id })
    }

    func testBandWithBookingCannotBeDeleted() throws {
        let booking = try book(15)
        XCTAssertThrowsError(try store.deleteAvailability(id: booking.availabilityId!, tutorId: tutor.id))
    }
}
