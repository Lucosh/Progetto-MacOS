import Foundation

/// Tutto lo stato dell'app, salvato come un unico file JSON.
public struct AppDatabase: Codable, Sendable {
    public var schemaVersion = 1
    public var nextId = 1
    public var settings = Settings()
    public var users: [User] = []
    public var subjects: [Subject] = []
    public var availabilities: [Availability] = []
    public var bookings: [Booking] = []
    public var cancellations: [CancellationRequest] = []
    public var transactions: [BalanceTransaction] = []
    public var notifications: [AppNotification] = []

    public init() {}
}

extension AppDatabase {
    mutating func makeId() -> Int {
        defer { nextId += 1 }
        return nextId
    }

    mutating func notify(_ userId: Int, title: String, body: String, at date: Date) {
        let id = makeId()
        notifications.append(AppNotification(id: id, userId: userId, title: title, body: body, readAt: nil, createdAt: date))
    }

    mutating func notifyAdmins(title: String, body: String, at date: Date) {
        for admin in users where admin.role == .admin && admin.isActive {
            notify(admin.id, title: title, body: body, at: date)
        }
    }

    mutating func addTransaction(
        userId: Int,
        amountCents: Int,
        type: TransactionType,
        description: String,
        bookingId: Int?,
        createdById: Int?,
        at date: Date
    ) {
        guard let index = users.firstIndex(where: { $0.id == userId }) else { return }
        users[index].balanceCents += amountCents
        let id = makeId()
        transactions.append(BalanceTransaction(
            id: id,
            userId: userId,
            amountCents: amountCents,
            type: type,
            description: description,
            bookingId: bookingId,
            createdById: createdById,
            createdAt: date
        ))
    }
}
