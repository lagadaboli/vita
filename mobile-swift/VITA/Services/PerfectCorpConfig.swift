import Foundation

/// Configuration for the Perfect Corp YouCam Skin Analysis API.
/// API key is stored in UserDefaults (same pattern as GeminiConfig).
///
/// Get your key at: https://yce.makeupar.com/api-console/en/api-keys/
struct PerfectCorpConfig {
    var apiKey: String

    static var current: PerfectCorpConfig {
        get {
            PerfectCorpConfig(
                apiKey: UserDefaults.standard.string(forKey: "perfectcorp.apiKey") ?? ""
            )
        }
        set {
            UserDefaults.standard.set(
                newValue.apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
                forKey: "perfectcorp.apiKey"
            )
        }
    }

    var isConfigured: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
