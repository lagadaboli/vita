import SwiftUI
import VITADesignSystem

struct FoxitCredentialsView: View {
    @State private var baseURL: String = FoxitConfig.current.baseURL
    @State private var documentClientId: String = FoxitConfig.current.documentGeneration.clientId
    @State private var documentClientSecret: String = FoxitConfig.current.documentGeneration.clientSecret
    @State private var pdfClientId: String = FoxitConfig.current.pdfServices.clientId
    @State private var pdfClientSecret: String = FoxitConfig.current.pdfServices.clientSecret
    @State private var isSaved = false

    private var isConfigured: Bool {
        !documentClientId.isEmpty &&
        !documentClientSecret.isEmpty &&
        !pdfClientId.isEmpty &&
        !pdfClientSecret.isEmpty &&
        !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

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
                TextField("Base URL", text: $baseURL)
                    .textContentType(.none)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
            } header: {
                Text("Foxit Endpoint")
            } footer: {
                Text("Default: \(FoxitConfig.defaultBaseURL)")
                    .font(VITATypography.caption2)
            }

            Section {
                TextField("Client ID", text: $documentClientId)
                    .textContentType(.none)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                SecureField("Client Secret", text: $documentClientSecret)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } header: {
                Text("Document Generation API")
            }

            Section {
                TextField("Client ID", text: $pdfClientId)
                    .textContentType(.none)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                SecureField("Client Secret", text: $pdfClientSecret)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } header: {
                Text("PDF Services API")
            } footer: {
                Text("Store separate app credentials for both Foxit APIs. Obtain keys from the Foxit Developer Portal.")
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
        FoxitConfig.current = FoxitConfig(
            baseURL: baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            documentGeneration: .init(
                clientId: documentClientId.trimmingCharacters(in: .whitespacesAndNewlines),
                clientSecret: documentClientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
            ),
            pdfServices: .init(
                clientId: pdfClientId.trimmingCharacters(in: .whitespacesAndNewlines),
                clientSecret: pdfClientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        )
        isSaved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isSaved = false
        }
    }
}
