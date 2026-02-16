import Foundation
import GRDB

/// GRDB wrapper providing type-safe access to the VITA SQLite database.
/// All health data is stored locally on-device — nothing leaves without explicit cloud sync.
public final class VITADatabase: Sendable {
    private let dbWriter: any DatabaseWriter

    /// Open or create the database at the given path.
    public init(path: String) throws {
        var config = Configuration()
        config.foreignKeysEnabled = true
        dbWriter = try DatabasePool(path: path, configuration: config)
        try migrate()
    }

    /// In-memory database for testing.
    public static func inMemory() throws -> VITADatabase {
        var config = Configuration()
        config.foreignKeysEnabled = true
        let queue = try DatabaseQueue(configuration: config)
        let instance = VITADatabase(dbWriter: queue)
        try instance.migrate()
        return instance
    }

    private init(dbWriter: any DatabaseWriter) {
        self.dbWriter = dbWriter
    }

    private func migrate() throws {
        try Migrations.run(on: dbWriter)
    }

    // MARK: - Database Access

    /// Perform a write transaction.
    public func write<T>(_ block: (Database) throws -> T) throws -> T {
        try dbWriter.write(block)
    }

    /// Perform a read-only access.
    public func read<T>(_ block: (Database) throws -> T) throws -> T {
        try dbWriter.read(block)
    }
}
