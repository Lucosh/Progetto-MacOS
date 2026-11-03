import XCTest
@testable import FeniceCore

final class AdminTests: XCTestCase {
    var clock: TestClock!
    var store: FeniceStore!
    var adminId: Int!
    var student: User!

    override func setUpWithError() throws {
        clock = TestClock(date(2026, 10, 12, 10))
        store = try makeStore(clock: clock)
        adminId = store.admin.id
        student = try store.registerStudent(firstName: "Marco", lastName: "Rossi", email: "marco@test.it", password: "password1")
    }

    private var balance: Int { store.user(student.id)!.balanceCents }

    func testCreateTutorAndLogin() throws {
        let tutor = try store.createUser(adminId: adminId, role: .tutor, firstName: "Luca", lastName: "Verdi", email: "luca@test.it", password: "password1")
        XCTAssertEqual(try store.login(email: "luca@test.it", password: "password1").role, .tutor)
        XCTAssertThrowsError(try store.createUser(adminId: student.id, role: .admin, firstName: "X", lastName: "", email: "x@test.it", password: "password1"))
        XCTAssertEqual(tutor.subjectIds, [])
    }

    func testBalanceOperations() throws {
        try store.adjustBalance(adminId: adminId, userId: student.id, operation: .setBalance, amountCents: -4000)
        XCTAssertEqual(balance, -4000)
        XCTAssertEqual(store.totalOutstandingCents, 4000)
        try store.adjustBalance(adminId: adminId, userId: student.id, operation: .payment, amountCents: 2500)
        XCTAssertEqual(balance, -1500)
        try store.adjustBalance(adminId: adminId, userId: student.id, operation: .credit, amountCents: 3000)
        XCTAssertEqual(balance, 1500)
        XCTAssertThrowsError(try store.adjustBalance(adminId: adminId, userId: student.id, operation: .payment, amountCents: 0))
        XCTAssertEqual(store.transactions(forUser: student.id).map(\.type), [.topUp, .payment, .adjustment])
    }

    func testDeactivatedUserCannotLogin() throws {
        try store.setUserActive(adminId: adminId, userId: student.id, active: false)
        XCTAssertThrowsError(try store.login(email: "marco@test.it", password: "password1"))
        XCTAssertThrowsError(try store.setUserActive(adminId: adminId, userId: adminId, active: false))
        try store.setUserActive(adminId: adminId, userId: student.id, active: true)
        XCTAssertNoThrow(try store.login(email: "marco@test.it", password: "password1"))
    }

    func testResetPassword() throws {
        try store.resetPassword(adminId: adminId, userId: student.id, newPassword: "nuovissima")
        XCTAssertNoThrow(try store.login(email: "marco@test.it", password: "nuovissima"))
    }

    func testUpdateUserRules() throws {
        try store.updateUser(adminId: adminId, userId: student.id, firstName: "Marco", lastName: "Neri", email: "marco.neri@test.it",
                             phone: "333", parent1Phone: "334", parent2Phone: "", role: .student)
        XCTAssertEqual(store.user(student.id)?.fullName, "Marco Neri")
        XCTAssertThrowsError(try store.updateUser(adminId: adminId, userId: student.id, firstName: "Marco", lastName: "", email: FeniceStore.defaultAdminEmail,
                                                  phone: "", parent1Phone: "", parent2Phone: "", role: .student))
        XCTAssertThrowsError(try store.updateUser(adminId: adminId, userId: adminId, firstName: "Admin", lastName: "", email: FeniceStore.defaultAdminEmail,
                                                  phone: "", parent1Phone: "", parent2Phone: "", role: .tutor))
    }

    func testSubjects() throws {
        let latin = try store.addSubject(adminId: adminId, name: "Latino", hourlyRateCents: 2500)
        XCTAssertEqual(store.price(subjectId: latin.id, durationMinutes: 60), 2500)
        XCTAssertThrowsError(try store.addSubject(adminId: adminId, name: "latino", hourlyRateCents: nil))
        XCTAssertThrowsError(try store.addSubject(adminId: adminId, name: "Greco", hourlyRateCents: 0))
        try store.updateSubject(adminId: adminId, subjectId: latin.id, name: "Latino", hourlyRateCents: nil)
        XCTAssertEqual(store.price(subjectId: latin.id, durationMinutes: 60), 2000)
        try store.updateHourlyRate(adminId: adminId, cents: 2200)
        XCTAssertEqual(store.price(subjectId: latin.id, durationMinutes: 60), 2200)
    }

    func testSubjectWithLessonsCannotBeDeleted() throws {
        let tutor = try store.makeTestTutor(teaching: ["Matematica"])
        let math = store.subjectId(named: "Matematica")
        try store.addAvailability(tutorId: tutor.id, start: date(2026, 10, 14, 15), end: date(2026, 10, 14, 19))
        try store.bookLesson(studentId: student.id, tutorId: tutor.id, subjectId: math, start: date(2026, 10, 14, 15),
                             durationMinutes: 60, canAdvance: false, note: "")
        XCTAssertThrowsError(try store.deleteSubject(adminId: adminId, subjectId: math))

        let physics = store.subjectId(named: "Fisica")
        try store.setTeaches(tutorId: tutor.id, subjectId: physics, enabled: true)
        try store.deleteSubject(adminId: adminId, subjectId: physics)
        XCTAssertNil(store.subject(physics))
        XCTAssertFalse(store.user(tutor.id)!.subjectIds.contains(physics))
    }

    func testDemoDataIsIdempotent() throws {
        try store.addDemoData(adminId: adminId)
        try store.addDemoData(adminId: adminId)
        XCTAssertEqual(store.db.users.filter { $0.email.hasSuffix("@demo.it") }.count, 2)
        let tutor = store.db.users.first { $0.email == "tutor@demo.it" }!
        XCTAssertEqual(store.availabilities(forTutor: tutor.id).count, 5)
        XCTAssertNoThrow(try store.login(email: "studente@demo.it", password: FeniceStore.demoPassword))
    }

    func testNotifications() throws {
        try store.adjustBalance(adminId: adminId, userId: student.id, operation: .credit, amountCents: 1000)
        XCTAssertEqual(store.unreadCount(forUser: student.id), 1)
        try store.markAllNotificationsRead(userId: student.id)
        XCTAssertEqual(store.unreadCount(forUser: student.id), 0)
    }
}
