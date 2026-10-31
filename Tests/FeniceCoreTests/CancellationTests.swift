import XCTest
@testable import FeniceCore

final class CancellationTests: XCTestCase {
    var clock: TestClock!
    var store: FeniceStore!
    var tutor: User!
    var student: User!
    var lesson: Booking!

    override func setUpWithError() throws {
        clock = TestClock(date(2026, 10, 12, 10))
        store = try makeStore(clock: clock)
        tutor = try store.makeTestTutor(teaching: ["Matematica"])
        student = try store.registerStudent(firstName: "Marco", lastName: "Rossi", email: "marco@test.it", password: "password1")
        try store.addAvailability(tutorId: tutor.id, start: date(2026, 10, 14, 15), end: date(2026, 10, 14, 19))
        lesson = try store.bookLesson(
            studentId: student.id, tutorId: tutor.id, subjectId: store.subjectId(named: "Matematica"),
            start: date(2026, 10, 14, 15), durationMinutes: 60, canAdvance: false, note: ""
        )
    }

    private var balance: Int { store.user(student.id)!.balanceCents }

    func testEarlyApprovedIsNeverCharged() throws {
        let request = try store.requestCancellation(bookingId: lesson.id, studentId: student.id, reason: "Ho un esame")
        XCTAssertTrue(request.isEarly)
        try store.decideCancellation(requestId: request.id, deciderId: tutor.id, approve: true)
        XCTAssertEqual(store.booking(lesson.id)?.status, .cancelled)

        clock.current = date(2026, 10, 14, 16)
        try store.runMaintenance()
        XCTAssertEqual(balance, 0)
        XCTAssertEqual(store.booking(lesson.id)?.status, .cancelled)
    }

    func testEarlyRequestDecidedAfterChargeIsRefunded() throws {
        clock.current = date(2026, 10, 14, 2)
        let request = try store.requestCancellation(bookingId: lesson.id, studentId: student.id, reason: "Febbre")
        XCTAssertTrue(request.isEarly)

        clock.current = date(2026, 10, 14, 4)
        try store.runMaintenance()
        XCTAssertEqual(balance, -2000)

        try store.decideCancellation(requestId: request.id, deciderId: tutor.id, approve: true)
        XCTAssertEqual(balance, 0)
        XCTAssertNotNil(store.booking(lesson.id)?.refundedAt)
        XCTAssertEqual(store.transactions(forUser: student.id).first?.type, .refund)
    }

    func testLateApprovedStaysCharged() throws {
        clock.current = date(2026, 10, 14, 9)
        try store.runMaintenance()
        let request = try store.requestCancellation(bookingId: lesson.id, studentId: student.id, reason: "Imprevisto")
        XCTAssertFalse(request.isEarly)
        try store.decideCancellation(requestId: request.id, deciderId: tutor.id, approve: true)
        XCTAssertEqual(store.booking(lesson.id)?.status, .cancelled)
        XCTAssertEqual(balance, -2000)
    }

    func testRejectedKeepsLessonAndCannotBeResubmitted() throws {
        let request = try store.requestCancellation(bookingId: lesson.id, studentId: student.id, reason: "Boh")
        try store.decideCancellation(requestId: request.id, deciderId: tutor.id, approve: false)
        XCTAssertEqual(store.booking(lesson.id)?.status, .confirmed)
        XCTAssertThrowsError(try store.requestCancellation(bookingId: lesson.id, studentId: student.id, reason: "Riprovo"))
        XCTAssertThrowsError(try store.decideCancellation(requestId: request.id, deciderId: store.admin.id, approve: true))
    }

    func testForwardToAdmin() throws {
        let request = try store.requestCancellation(bookingId: lesson.id, studentId: student.id, reason: "Gita")
        try store.forwardCancellation(requestId: request.id, tutorId: tutor.id)
        XCTAssertEqual(store.openCancellations().first?.status, .forwarded)
        XCTAssertTrue(store.db.notifications.contains { $0.userId == store.admin.id && $0.title == "Annullamento da decidere" })

        try store.decideCancellation(requestId: request.id, deciderId: store.admin.id, approve: true)
        XCTAssertEqual(store.cancellation(forBooking: lesson.id)?.decidedById, store.admin.id)
        XCTAssertTrue(store.openCancellations().isEmpty)
    }

    func testOnlyOwnTutorCanDecide() throws {
        let other = try store.makeTestTutor(email: "altro@test.it", teaching: ["Matematica"])
        let request = try store.requestCancellation(bookingId: lesson.id, studentId: student.id, reason: "Gita")
        XCTAssertThrowsError(try store.decideCancellation(requestId: request.id, deciderId: other.id, approve: true))
        XCTAssertThrowsError(try store.decideCancellation(requestId: request.id, deciderId: student.id, approve: true))
        XCTAssertThrowsError(try store.forwardCancellation(requestId: request.id, tutorId: other.id))
    }

    func testRequestRules() throws {
        XCTAssertThrowsError(try store.requestCancellation(bookingId: lesson.id, studentId: student.id, reason: "   "))
        clock.current = date(2026, 10, 14, 15, 10)
        XCTAssertThrowsError(try store.requestCancellation(bookingId: lesson.id, studentId: student.id, reason: "Troppo tardi"))
    }

    func testUndecidedRequestExpiresAfterLesson() throws {
        let request = try store.requestCancellation(bookingId: lesson.id, studentId: student.id, reason: "Forse")
        clock.current = date(2026, 10, 14, 16)
        try store.runMaintenance()
        XCTAssertEqual(store.cancellation(forBooking: lesson.id)?.status, .expired)
        XCTAssertThrowsError(try store.decideCancellation(requestId: request.id, deciderId: tutor.id, approve: true))
    }
}
