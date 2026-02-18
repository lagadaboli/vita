import Foundation

/// Shared payload for Watch nudge notifications.
/// Used by both iPhone (sender) and Watch (receiver) via WCSession.
public struct WatchNudgePayload: Codable, Sendable {
    public let symptom: String
    public let nudgeText: String      // ≤15 words
    public let actionText: String
    public let confidence: Double
    public let timestamp: Date
    public let causeType: String

    public init(
        symptom: String,
        nudgeText: String,
        actionText: String,
        confidence: Double,
        timestamp: Date,
        causeType: String
    ) {
        self.symptom = symptom
        self.nudgeText = nudgeText
        self.actionText = actionText
        self.confidence = confidence
        self.timestamp = timestamp
        self.causeType = causeType
    }

    /// Encode to dictionary for WCSession transfer.
    public func toDictionary() -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(self),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return dict
    }

    /// Decode from WCSession dictionary.
    public static func from(dictionary: [String: Any]) -> WatchNudgePayload? {
        guard let data = try? JSONSerialization.data(withJSONObject: dictionary) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WatchNudgePayload.self, from: data)
    }
}
