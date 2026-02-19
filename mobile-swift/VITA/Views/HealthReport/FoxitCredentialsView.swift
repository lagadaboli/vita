import SwiftUI
import VITADesignSystem

struct FoxitCredentialsView: View {
    @State private var clientId: String = FoxitConfig.current.clientId
    @State private var clientSecret: String = FoxitConfig.current.clientSecret
    @State private var isSaved = false

    private var isConfigured: Bool { !clientId.isEmpty && !clientSecret.isEmpty }

    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: isConfigured ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isConfigured ? VITAColors.success : VITAColors.textTertiary)
                    Text(isConfigured ? "Configured" : "Not configured")
                        .foregroundStyle(isConfigured ? VITAColors.success : VITAColors.textSecondary)
                }
            } header: {
                Text("API Status")
            }

            Section {
                SecureField("Client ID", text: $clientId)
                    .textContentType(.none)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                SecureField("Client Secret", text: $clientSecret)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } header: {
                Text("Foxit API Credentials")
            } footer: {
                Text("Credentials are stored securely in UserDefaults on your device. Obtain them from the Foxit Developer Portal.")
                    .font(VITATypography.caption2)
            }

            Section {
                Button {
                    saveCredentials()
                } label: {
                    HStack {
                        Spacer()
                        Text(isSaved ? "Saved!" : "Save Credentials")
                            .fontWeight(.semibold)
                            .foregroundStyle(isSaved ? VITAColors.success : VITAColors.teal)
                        Spacer()
                    }
                }
                .disabled(isSaved)
            }
        }
        .navigationTitle("Foxit Credentials")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func saveCredentials() {
        var config = FoxitConfig.current
        config.clientId = clientId
        config.clientSecret = clientSecret
        FoxitConfig.current = config
        isSaved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isSaved = false
        }
    }
}
