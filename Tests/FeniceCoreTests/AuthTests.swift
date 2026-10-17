import XCTest
@testable import FeniceCore

final class AuthTests: XCTestCase {
    var clock: TestClock!
    var store: FeniceStore!

    override func setUpWithError() throws {
        clock = TestClock(date(2026, 10, 12, 10))
        store = try makeStore(clock: clock)
    }

    func testSeedCreatesAdminAndSubjects() throws {
        XCTAssertEqual(store.subjects.count, 5)
        let admin = try store.login(email: FeniceStore.defaultAdminEmail, password: FeniceStore.defaultAdminPassword)
        XCTAssertEqual(admin.role, .admin)
    }

    func testLoginIgnoresEmailCase() throws {
        XCTAssertNoThrow(try store.login(email: "  ADMIN@ardentisfenice.it ", password: "admin1234"))
    }

    func testWrongPassword() {
        XCTAssertThrowsError(try store.login(email: FeniceStore.defaultAdminEmail, password: "sbagliata"))
    }

    func testRegisterStudent() throws {
        let student = try store.registerStudent(firstName: "Marco", lastName: "Rossi", email: "marco@test.it", password: "password1")
        XCTAssertEqual(student.role, .student)
        XCTAssertEqual(student.balanceCents, 0)
        XCTAssertEqual(try store.login(email: "marco@test.it", password: "password1").id, student.id)
    }

    func testRegisterRejectsDuplicatesAndBadInput() throws {
        try store.registerStudent(firstName: "Marco", lastName: "", email: "marco@test.it", password: "password1")
        XCTAssertThrowsError(try store.registerStudent(firstName: "Altro", lastName: "", email: "Marco@test.it", password: "password1"))
        XCTAssertThrowsError(try store.registerStudent(firstName: "Anna", lastName: "", email: "anna@test", password: "password1"))
        XCTAssertThrowsError(try store.registerStudent(firstName: "Anna", lastName: "", email: "anna@test.it", password: "corta"))
        XCTAssertThrowsError(try store.registerStudent(firstName: " ", lastName: "", email: "anna@test.it", password: "password1"))
    }

    func testChangePassword() throws {
        let student = try store.registerStudent(firstName: "Marco", lastName: "", email: "marco@test.it", password: "password1")
        XCTAssertThrowsError(try store.changePassword(userId: student.id, currentPassword: "nonlaso", newPassword: "nuovapass"))
        try store.changePassword(userId: student.id, currentPassword: "password1", newPassword: "nuovapass")
        XCTAssertNoThrow(try store.login(email: "marco@test.it", password: "nuovapass"))
        XCTAssertThrowsError(try store.login(email: "marco@test.it", password: "password1"))
    }

    func testFailedRegistrationLeavesStateUntouched() throws {
        let before = store.db.users.count
        XCTAssertThrowsError(try store.registerStudent(firstName: "Anna", lastName: "", email: "x", password: "password1"))
        XCTAssertEqual(store.db.users.count, before)
    }
}
