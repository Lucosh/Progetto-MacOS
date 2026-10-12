import Foundation

/// Fascia di disponibilità di un tutor: dentro la fascia si prenota con inizio ogni 30 minuti.
public struct Availability: Codable, Identifiable, Hashable, Sendable {
    public let id: Int
    public let tutorId: Int
    public var start: Date
    public var end: Date
}

public enum BookingStatus: String, Codable, CaseIterable, Sendable {
    case confirmed = "CONFIRMED"
    case cancelled = "CANCELLED"
    case completed = "COMPLETED"

    public var label: String {
        switch self {
        case .confirmed: return "Confermata"
        case .cancelled: return "Annullata"
        case .completed: return "Svolta"
        }
    }
}

public struct Booking: Codable, Identifiable, Hashable, Sendable {
    public let id: Int
    public let studentId: Int
    public let tutorId: Int
    public let subjectId: Int
    public var availabilityId: Int?
    public var start: Date
    public var end: Date
    public var durationMinutes: Int
    public var canAdvance: Bool
    public var note: String
    public var priceCents: Int
    public var status: BookingStatus
    public var chargedAt: Date?
    public var refundedAt: Date?
    public let createdAt: Date
}
