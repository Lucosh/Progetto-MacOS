import Foundation
@testable import FeniceCore

struct FakeHasher: PasswordHasher {
    func hash(password: String, salt: String) -> String {
        "\(salt):\(password)"
    }
}

final class TestClock {
    var current: Date

    init(_ date: Date) {
        current = date
    }

    func advance(hours: Double) {
        current = current.addingTimeInterval(hours * 3600)
    }
}

let romeCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Rome")!
    return calendar
}()

func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
    romeCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

func makeStore(clock: TestClock) throws -> FeniceStore {
    try FeniceStore(
        persistence: InMemoryPersistence(),
        hasher: FakeHasher(),
        calendar: romeCalendar,
        now: { clock.current }
    )
}

extension FeniceStore {
    var admin: User {
        db.users.first { $0.role == .admin }!
    }

    func subjectId(named name: String) -> Int {
        db.subjects.first { $0.name == name }!.id
    }
}
