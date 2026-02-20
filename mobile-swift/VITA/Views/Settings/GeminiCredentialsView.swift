import SwiftUI
import VITADesignSystem

struct GeminiCredentialsView: View {
    @State private var apiKey: String = GeminiConfig.current.apiKey
    @State private var selectedModel: String = GeminiConfig.current.model
    @State private var isSaved = false

    private var isConfigured: Bool { !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: isConfigured ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isConfigured ? VITAColors.success : VITAColors.textTertiary)
                    Text(isConfigured ? "Configured — AI chat enabled" : "Not configured")
                        .foregroundStyle(isConfigured ? VITAColors.success : VITAColors.textSecondary)
                }
            } header: {
                Text("Status")
            }

            Section {
                SecureField("Gemini API Key", text: $apiKey)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .font(VITATypography.body)
            } header: {
                Text("API Key")
            } footer: {
                Text("Get a free key at aistudio.google.com → Get API Key. Free tier: 1,500 requests/day, 1M tokens/day.")
                    .font(VITATypography.caption2)
            }

            Section {
                Picker("Model", selection: $selectedModel) {
                    ForEach(GeminiConfig.availableModels, id: \.id) { model in
                        Text(model.label).tag(model.id)
                    }
                }
            } header: {
                Text("Model")
            } footer: {
                Text("Gemini 2.0 Flash is recommended. Gemma 3n is a lighter option for faster/cheaper runs.")
                    .font(VITATypography.caption2)
            }

            Section {
                Button {
                    saveCredentials()
                } label: {
                    HStack {
                        Spacer()
                        Text(isSaved ? "Saved!" : "Save")
                            .fontWeight(.semibold)
                            .foregroundStyle(isSaved ? VITAColors.success : VITAColors.teal)
                        Spacer()
                    }
                }
                .disabled(isSaved)
            }
        }
        .navigationTitle("Ask VITA AI")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func saveCredentials() {
        GeminiConfig.current = GeminiConfig(
            apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
            model: selectedModel
        )
        isSaved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isSaved = false
        }
    }
}
