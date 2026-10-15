import Foundation

extension FeniceStore {
    public var settings: Settings { db.settings }

    public var allUsers: [User] {
        db.users.sorted { $0.fullName.localizedCaseInsensitiveCompare($1.fullName) == .orderedAscending }
    }

    public var subjects: [Subject] {
        db.subjects.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public func user(_ id: Int) -> User? {
        db.users.first { $0.id == id }
    }

    public func subject(_ id: Int) -> Subject? {
        db.subjects.first { $0.id == id }
    }

    public func booking(_ id: Int) -> Booking? {
        db.bookings.first { $0.id == id }
    }

    public func userName(_ id: Int) -> String {
        user(id)?.fullName ?? "Utente sconosciuto"
    }

    public func subjectName(_ id: Int) -> String {
        subject(id)?.name ?? "Materia eliminata"
    }
}
