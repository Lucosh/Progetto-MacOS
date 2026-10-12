import Foundation

public enum CancellationStatus: String, Codable, CaseIterable, Sendable {
    case pending = "PENDING"
    case forwarded = "FORWARDED"
    case approved = "APPROVED"
    case rejected = "REJECTED"
    /// la lezione è passata senza che nessuno decidesse
    case expired = "EXPIRED"

    public var label: String {
        switch self {
        case .pending: return "In attesa"
        case .forwarded: return "Inoltrata"
        case .approved: return "Approvata"
        case .rejected: return "Rifiutata"
        case .expired: return "Scaduta"
        }
    }

    public var isOpen: Bool {
        self == .pending || self == .forwarded
    }
}

public struct CancellationRequest: Codable, Identifiable, Hashable, Sendable {
    public let id: Int
    public let bookingId: Int
    public let requestedById: Int
    public let reason: String
    public let requestedAt: Date
    /// true se chiesta almeno 12 ore prima: se approvata la lezione non si paga
    public let isEarly: Bool
    public var status: CancellationStatus
    public var decidedById: Int?
    public var decidedAt: Date?
}
