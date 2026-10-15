import Foundation

public protocol Persistence {
    func load() throws -> AppDatabase?
    func save(_ db: AppDatabase) throws
}

public final class JSONFilePersistence: Persistence {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// ~/Library/Application Support/GestionaleFenice/database.json
    public static func defaultURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("GestionaleFenice", isDirectory: true)
            .appendingPathComponent("database.json")
    }

    public func load() throws -> AppDatabase? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        do {
            return try JSONDecoder().decode(AppDatabase.self, from: data)
        } catch {
            // file illeggibile: lo metto da parte invece di cancellarlo e riparto da zero
            let stamp = Int(Date().timeIntervalSince1970)
            let broken = url.deletingLastPathComponent().appendingPathComponent("database-illeggibile-\(stamp).json")
            try? FileManager.default.moveItem(at: url, to: broken)
            return nil
        }
    }

    public func save(_ db: AppDatabase) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(db).write(to: url, options: .atomic)
    }
}

/// Usata dai test e dalle anteprime.
public final class InMemoryPersistence: Persistence {
    public private(set) var saved: AppDatabase?

    public init(_ initial: AppDatabase? = nil) {
        saved = initial
    }

    public func load() throws -> AppDatabase? { saved }

    public func save(_ db: AppDatabase) throws {
        saved = db
    }
}
