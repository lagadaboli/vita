import Foundation

struct IntegrationHistoryEvent: Codable {
    let source: String
    let category: String
    let item: String
    let timestamp: Date
    let notes: [String]
}

struct IntegrationHistoryPayload: Codable {
    let generatedAt: Date
    let events: [IntegrationHistoryEvent]
}

enum IntegrationHistoryStore {
    private static let fileName = "integration_history_30d.json"

    private static var fileURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent(fileName)
    }

    static func save(events: [IntegrationHistoryEvent], generatedAt: Date = Date()) {
        guard let fileURL else { return }
        let payload = IntegrationHistoryPayload(generatedAt: generatedAt, events: events.sorted { $0.timestamp < $1.timestamp })
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(payload)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            #if DEBUG
            print("[IntegrationHistoryStore] save failed: \(error)")
            #endif
        }
    }

    static func load() -> IntegrationHistoryPayload? {
        guard let fileURL else { return nil }
        guard let data = try? Data(contentsOf: fileURL) else { return nil }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(IntegrationHistoryPayload.self, from: data)
    }

    static func buildPromptSummary(now: Date = Date()) -> String? {
        guard let payload = load(), !payload.events.isEmpty else { return nil }

        let cutoff30d = now.addingTimeInterval(-30 * 86_400)
        let cutoff7d = now.addingTimeInterval(-7 * 86_400)
        let cutoff24h = now.addingTimeInterval(-24 * 3_600)

        let events30d = payload.events.filter { $0.timestamp >= cutoff30d }
        guard !events30d.isEmpty else { return nil }

        let events7d = events30d.filter { $0.timestamp >= cutoff7d }
        let events24h = events30d.filter { $0.timestamp >= cutoff24h }

        let categories = Dictionary(grouping: events30d, by: { $0.category })
            .mapValues(\.count)
            .sorted { $0.value > $1.value }

        let topCategories = categories.prefix(5)
            .map { "\($0.key): \($0.value)" }
            .joined(separator: ", ")

        let topItems7d = Dictionary(grouping: events7d, by: { "\($0.category): \($0.item)" })
            .mapValues(\.count)
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { "\($0.key) (\($0.value)x)" }
            .joined(separator: ", ")

        return """
          30d events: \(events30d.count), last 7d: \(events7d.count), last 24h: \(events24h.count)
          Top categories: \(topCategories)
          Frequent in 7d: \(topItems7d.isEmpty ? "none" : topItems7d)
        """
    }
}
