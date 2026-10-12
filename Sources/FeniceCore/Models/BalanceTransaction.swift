import Foundation

public enum TransactionType: String, Codable, CaseIterable, Sendable {
    case charge = "CHARGE"
    case refund = "REFUND"
    case topUp = "TOPUP"
    case payment = "PAYMENT"
    case adjustment = "SET"

    public var label: String {
        switch self {
        case .charge: return "Addebito"
        case .refund: return "Storno"
        case .topUp: return "Credito"
        case .payment: return "Pagamento"
        case .adjustment: return "Correzione"
        }
    }
}

public struct BalanceTransaction: Codable, Identifiable, Hashable, Sendable {
    public let id: Int
    public let userId: Int
    public let amountCents: Int
    public let type: TransactionType
    public let description: String
    public let bookingId: Int?
    public let createdById: Int?
    public let createdAt: Date
}

public struct AppNotification: Codable, Identifiable, Hashable, Sendable {
    public let id: Int
    public let userId: Int
    public let title: String
    public let body: String
    public var readAt: Date?
    public let createdAt: Date

    public var isRead: Bool { readAt != nil }
}
