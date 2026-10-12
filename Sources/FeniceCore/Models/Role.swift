import Foundation

public enum Role: String, Codable, CaseIterable, Identifiable, Sendable {
    case student = "STUDENT"
    case tutor = "TUTOR"
    case admin = "ADMIN"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .student: return "Studente"
        case .tutor: return "Tutor"
        case .admin: return "Admin"
        }
    }
}
