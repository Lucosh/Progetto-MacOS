import XCTest
@testable import FeniceCore

final class BillingTests: XCTestCase {
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
        try store.addAvailability(tutorId: tutor.id, start: date(2026, 10, 12, 18), end: date(2026, 10, 12, 21))
        try store.addAvailability(tutorId: tutor.id, start: date(2026, 10, 14, 15), end: date(2026, 10, 14, 19))
    }

    private func book(_ start: Date) throws -> Booking {
        try store.bookLesson(
            studentId: student.id, tutorId: tutor.id, subjectId: math,
            start: start, durationMinutes: 60, canAdvance: false, note: ""
        )
    }

    private var balance: Int { store.user(student.id)!.balanceCents }

    func testFarBookingIsNotChargedYet() throws {
        let booking = try book(date(2026, 10, 14, 15))
        XCTAssertNil(booking.chargedAt)
        XCTAssertEqual(balance, 0)
    }

    func testBookingWithinTwelveHoursIsChargedImmediately() throws {
        let booking = try book(date(2026, 10, 12, 18))
        XCTAssertNotNil(booking.chargedAt)
        XCTAssertEqual(balance, -2000)
        XCTAssertEqual(store.transactions(forUser: student.id).first?.type, .charge)
    }

    func testMaintenanceChargesTwelveHoursBefore() throws {
        let booking = try book(date(2026, 10, 14, 15))
        clock.current = date(2026, 10, 14, 2, 59)
        try store.runMaintenance()
        XCTAssertNil(store.booking(booking.id)?.chargedAt)

        clock.current = date(2026, 10, 14, 3)
        try store.runMaintenance()
        XCTAssertNotNil(store.booking(booking.id)?.chargedAt)
        XCTAssertEqual(balance, -2000)

        try store.runMaintenance()
        XCTAssertEqual(balance, -2000, "non deve addebitare due volte")
    }

    func testFinishedLessonsBecomeCompleted() throws {
        let booking = try book(date(2026, 10, 14, 15))
        clock.current = date(2026, 10, 14, 16)
        try store.runMaintenance()
        XCTAssertEqual(store.booking(booking.id)?.status, .completed)
        XCTAssertEqual(balance, -2000)
        XCTAssertTrue(store.freeSlots(tutorId: tutor.id, studentId: nil, durationMinutes: 60).contains { $0.start == date(2026, 10, 14, 17) })
    }

    func testReloadKeepsSeedData() throws {
        let persistence = InMemoryPersistence()
        let first = try FeniceStore(persistence: persistence, hasher: FakeHasher(), calendar: romeCalendar, now: { self.clock.current })
        let reloaded = try FeniceStore(persistence: persistence, hasher: FakeHasher(), calendar: romeCalendar, now: { self.clock.current })
        XCTAssertEqual(first.db.users.count, reloaded.db.users.count)
        XCTAssertEqual(first.db.nextId, reloaded.db.nextId)
    }
}
