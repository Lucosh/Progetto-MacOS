import Foundation

public struct FeniceError: LocalizedError, Equatable {
    public let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var errorDescription: String? { message }
}

public protocol PasswordHasher {
    func hash(password: String, salt: String) -> String
}

public final class FeniceStore {
    public private(set) var db: AppDatabase
    public var calendar: Calendar
    public var now: () -> Date

    let persistence: Persistence
    let hasher: PasswordHasher

    public init(
        persistence: Persistence,
        hasher: PasswordHasher,
        calendar: Calendar = .current,
        now: @escaping () -> Date = { Date() }
    ) throws {
        self.persistence = persistence
        self.hasher = hasher
        self.calendar = calendar
        self.now = now
        if let saved = try persistence.load() {
            db = saved
        } else {
            db = FeniceStore.seededDatabase(hasher: hasher, date: now())
            try persistence.save(db)
        }
    }

    /// Le modifiche lavorano su una copia: se qualcosa fallisce lo stato resta com'era.
    func mutate<T>(_ body: (inout AppDatabase) throws -> T) throws -> T {
        var copy = db
        let result = try body(&copy)
        try persistence.save(copy)
        db = copy
        return result
    }
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
