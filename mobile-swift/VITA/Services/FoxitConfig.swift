import Foundation

struct FoxitConfig {
    struct Credentials {
        var clientId: String
        var clientSecret: String

        var isConfigured: Bool {
            !clientId.isEmpty && !clientSecret.isEmpty
        }
    }

    var baseURL: String
    var documentGeneration: Credentials
    var pdfServices: Credentials

    static let defaultBaseURL = "https://na1.fusion.foxit.com"
    static var baseURL: String { current.baseURL }

    static var current: FoxitConfig {
        get {
            let defaults = UserDefaults.standard

            // Backward compatibility with the previous single-credential config.
            let legacyClientId = defaults.string(forKey: "foxit.clientId") ?? ""
            let legacyClientSecret = defaults.string(forKey: "foxit.clientSecret") ?? ""

            let configuredBaseURL = defaults.string(forKey: "foxit.baseURL")?.trimmingCharacters(in: .whitespacesAndNewlines)
            let baseURL = (configuredBaseURL?.isEmpty == false) ? configuredBaseURL! : defaultBaseURL

            return FoxitConfig(
                baseURL: baseURL,
                documentGeneration: Credentials(
                    clientId: defaults.string(forKey: "foxit.document.clientId") ?? legacyClientId,
                    clientSecret: defaults.string(forKey: "foxit.document.clientSecret") ?? legacyClientSecret
                ),
                pdfServices: Credentials(
                    clientId: defaults.string(forKey: "foxit.pdf.clientId") ?? legacyClientId,
                    clientSecret: defaults.string(forKey: "foxit.pdf.clientSecret") ?? legacyClientSecret
                )
            )
        }
        set {
            let defaults = UserDefaults.standard
            defaults.set(newValue.baseURL, forKey: "foxit.baseURL")
            defaults.set(newValue.documentGeneration.clientId, forKey: "foxit.document.clientId")
            defaults.set(newValue.documentGeneration.clientSecret, forKey: "foxit.document.clientSecret")
            defaults.set(newValue.pdfServices.clientId, forKey: "foxit.pdf.clientId")
            defaults.set(newValue.pdfServices.clientSecret, forKey: "foxit.pdf.clientSecret")
        }
    }

    var isConfigured: Bool {
        documentGeneration.isConfigured && pdfServices.isConfigured
    }
}
