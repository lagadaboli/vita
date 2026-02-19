import Foundation
import CryptoKit
#if canImport(UIKit)
import UIKit
#endif

/// Client for posting SMS escalation requests to the backend.
/// Twilio credentials stay server-side only — this client only sends hashed identifiers.
struct EscalationClient: Sendable {
    private let baseURL: URL

    init(baseURL: URL = URL(string: "http://localhost:8000")!) {
        self.baseURL = baseURL
    }

    /// POST /notifications/escalate with symptom, reason, and confidence.
    func escalate(
        symptom: String,
        reason: String,
        confidence: Double
    ) async {
        let url = baseURL.appendingPathComponent("notifications/escalate")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "symptom": symptom,
            "escalation_reason": reason,
            "confidence_score": confidence,
            "phone_number_hash": phoneNumberHash(),
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (_, response) = try await URLSession.shared.data(for: request)

            #if DEBUG
            if let http = response as? HTTPURLResponse {
                print("[EscalationClient] POST /notifications/escalate → \(http.statusCode)")
            }
            #endif
        } catch {
            #if DEBUG
            print("[EscalationClient] Escalation failed: \(error)")
            #endif
        }
    }

    /// SHA-256 hash of a device-stable identifier. Never sends plaintext phone number.
    private func phoneNumberHash() -> String {
        // Use vendor ID as a stable device identifier (no actual phone number)
        #if canImport(UIKit)
        let identifier = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        #else
        let identifier = "unknown"
        #endif

        let hash = SHA256.hash(data: Data(identifier.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
