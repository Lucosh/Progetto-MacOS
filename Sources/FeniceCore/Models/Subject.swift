import Foundation

public struct Subject: Codable, Identifiable, Hashable, Sendable {
    public let id: Int
    public var name: String
    /// nil = si usa la tariffa globale delle impostazioni
    public var hourlyRateCents: Int?
}

public struct Settings: Codable, Hashable, Sendable {
    public var hourlyRateCents: Int = 2000

    public init() {}
}
