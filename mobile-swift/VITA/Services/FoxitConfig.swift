import Foundation

struct FoxitConfig {
    var clientId: String
    var clientSecret: String

    static let baseURL = "https://na1.fusion.foxit.com"

    static var current: FoxitConfig {
        get {
            FoxitConfig(
                clientId: UserDefaults.standard.string(forKey: "foxit.clientId") ?? "",
                clientSecret: UserDefaults.standard.string(forKey: "foxit.clientSecret") ?? ""
            )
        }
        set {
            UserDefaults.standard.set(newValue.clientId, forKey: "foxit.clientId")
            UserDefaults.standard.set(newValue.clientSecret, forKey: "foxit.clientSecret")
        }
    }

    var isConfigured: Bool { !clientId.isEmpty && !clientSecret.isEmpty }
}
