import Foundation

public struct User: Codable, Identifiable, Hashable, Sendable {
    public let id: Int
    public var email: String
    public var passwordHash: String
    public var passwordSalt: String
    public var role: Role
    public var firstName: String
    public var lastName: String
    public var phone: String
    public var parent1Phone: String
    public var parent2Phone: String
    /// negativo = da pagare, positivo = credito
    public var balanceCents: Int
    public var isActive: Bool
    /// solo per i tutor: le materie che insegna
    public var subjectIds: [Int]
    public let createdAt: Date

    public var fullName: String {
        lastName.isEmpty ? firstName : "\(firstName) \(lastName)"
    }

    public var initials: String {
        let letters = [firstName.first, lastName.first].compactMap { $0 }
        return String(letters).uppercased()
    }
}
