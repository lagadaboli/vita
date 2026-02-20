import Foundation

public struct WatchNudgePayload: Codable, Sendable, Equatable {
    public let id: UUID
    public let title: String
    public let message: String
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        message: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.message = message
        self.createdAt = createdAt
    }
}
