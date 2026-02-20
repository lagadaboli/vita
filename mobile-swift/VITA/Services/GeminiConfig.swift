import Foundation

/// Configuration for Gemini API access.
/// API key is stored in UserDefaults (same pattern as FoxitConfig).
///
/// Recommended model: gemini-2.0-flash — latest free tier model, fast, 1M context.
/// Free tier limits: 15 RPM, 1,500 RPD, 1M TPM.
struct GeminiConfig {
    var apiKey: String
    var model: String

    static let defaultModel = "gemini-2.0-flash"

    // Available Gemini/Gemma models for selection
    static let availableModels: [(id: String, label: String)] = [
        ("gemini-2.0-flash",      "Gemini 2.0 Flash (recommended)"),
        ("gemini-2.0-flash-lite", "Gemini 2.0 Flash Lite (fastest)"),
        ("gemini-1.5-flash",      "Gemini 1.5 Flash (stable)"),
        ("gemma-3n-e2b-it",       "Gemma 3n E2B (light)")
    ]

    static var current: GeminiConfig {
        get {
            let defaults = UserDefaults.standard
            return GeminiConfig(
                apiKey: defaults.string(forKey: "gemini.apiKey") ?? "",
                model: defaults.string(forKey: "gemini.model") ?? defaultModel
            )
        }
        set {
            let defaults = UserDefaults.standard
            defaults.set(newValue.apiKey.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "gemini.apiKey")
            defaults.set(newValue.model, forKey: "gemini.model")
        }
    }

    var isConfigured: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
