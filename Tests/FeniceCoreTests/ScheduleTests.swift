import XCTest
@testable import FeniceCore

final class ScheduleTests: XCTestCase {
    var clock: TestClock!
    var store: FeniceStore!
    var tutor: User!

    override func setUpWithError() throws {
        clock = TestClock(date(2026, 10, 12, 10))
        store = try makeStore(clock: clock)
        tutor = try store.makeTestTutor(teaching: ["Matematica"])
    }

    func testSlotsEveryHalfHourInsideBand() throws {
        try store.addAvailability(tutorId: tutor.id, start: date(2026, 10, 13, 15), end: date(2026, 10, 13, 19))

        let hour = store.freeSlots(tutorId: tutor.id, studentId: nil, durationMinutes: 60)
        let expected = [(15, 0), (15, 30), (16, 0), (16, 30), (17, 0), (17, 30), (18, 0)].map { date(2026, 10, 13, $0.0, $0.1) }
        XCTAssertEqual(hour.map(\.start), expected)

        let twoHours = store.freeSlots(tutorId: tutor.id, studentId: nil, durationMinutes: 120)
        XCTAssertEqual(twoHours.count, 5)
        XCTAssertEqual(twoHours.last?.end, date(2026, 10, 13, 19))
    }

    func testPastSlotsAreHidden() throws {
        try store.addAvailability(tutorId: tutor.id, start: date(2026, 10, 12, 11), end: date(2026, 10, 12, 14))
        clock.current = date(2026, 10, 12, 12, 10)
        let slots = store.freeSlots(tutorId: tutor.id, studentId: nil, durationMinutes: 60)
        XCTAssertEqual(slots.map(\.start), [date(2026, 10, 12, 12, 30), date(2026, 10, 12, 13)])
    }

    func testBandValidation() {
        let id = tutor.id
        XCTAssertThrowsError(try store.addAvailability(tutorId: id, start: date(2026, 10, 13, 19), end: date(2026, 10, 13, 18)))
        XCTAssertThrowsError(try store.addAvailability(tutorId: id, start: date(2026, 10, 13, 18, 15), end: date(2026, 10, 13, 20)))
        XCTAssertThrowsError(try store.addAvailability(tutorId: id, start: date(2026, 10, 13, 22), end: date(2026, 10, 13, 23, 45)))
        XCTAssertThrowsError(try store.addAvailability(tutorId: id, start: date(2026, 10, 13, 18), end: date(2026, 10, 13, 18, 30)))
        XCTAssertThrowsError(try store.addAvailability(tutorId: id, start: date(2026, 10, 11, 18), end: date(2026, 10, 11, 20)))
        XCTAssertThrowsError(try store.addAvailability(tutorId: store.admin.id, start: date(2026, 10, 13, 18), end: date(2026, 10, 13, 20)))
        XCTAssertNoThrow(try store.addAvailability(tutorId: id, start: date(2026, 10, 13, 22), end: date(2026, 10, 13, 23, 30)))
    }

    func testOverlappingBandsAreRejected() throws {
        try store.addAvailability(tutorId: tutor.id, start: date(2026, 10, 13, 15), end: date(2026, 10, 13, 18))
        XCTAssertThrowsError(try store.addAvailability(tutorId: tutor.id, start: date(2026, 10, 13, 17), end: date(2026, 10, 13, 19)))
        XCTAssertNoThrow(try store.addAvailability(tutorId: tutor.id, start: date(2026, 10, 13, 18), end: date(2026, 10, 13, 20)))
    }

    func testDeleteBand() throws {
        let band = try store.addAvailability(tutorId: tutor.id, start: date(2026, 10, 13, 15), end: date(2026, 10, 13, 18))
        try store.deleteAvailability(id: band.id, tutorId: tutor.id)
        XCTAssertTrue(store.availabilities(forTutor: tutor.id).isEmpty)
    }

    func testTeachesToggle() throws {
        let physics = store.subjectId(named: "Fisica")
        try store.setTeaches(tutorId: tutor.id, subjectId: physics, enabled: true)
        try store.setTeaches(tutorId: tutor.id, subjectId: physics, enabled: true)
        XCTAssertEqual(store.user(tutor.id)?.subjectIds.filter { $0 == physics }.count, 1)
        XCTAssertEqual(store.tutors(teaching: physics).map(\.id), [tutor.id])
        try store.setTeaches(tutorId: tutor.id, subjectId: physics, enabled: false)
        XCTAssertTrue(store.tutors(teaching: physics).isEmpty)
    }
}
