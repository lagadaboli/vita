import SwiftUI
import VITADesignSystem

struct PerfectCorpCredentialsView: View {
    @State private var apiKey: String = PerfectCorpConfig.current.apiKey
    @State private var isSaved = false

    var body: some View {
        Form {
            Section {
                SecureField("Bearer API Key", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("PerfectCorp YouCam API Key")
            } footer: {
                Text("Get your key at yce.makeupar.com → API Keys. The key is stored securely in UserDefaults on-device only.")
            }

            Section {
                Button("Save Key") {
                    var config = PerfectCorpConfig.current
                    config.apiKey = apiKey
                    PerfectCorpConfig.current = config
                    withAnimation { isSaved = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { isSaved = false }
                    }
                }
                .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if PerfectCorpConfig.current.isConfigured {
                    Button("Remove Key", role: .destructive) {
                        apiKey = ""
                        var config = PerfectCorpConfig.current
                        config.apiKey = ""
                        PerfectCorpConfig.current = config
                    }
                }
            }

            if isSaved {
                Section {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(VITAColors.success)
                        Text("API key saved — real skin analysis is now enabled.")
                            .font(VITATypography.caption)
                            .foregroundStyle(VITAColors.success)
                    }
                }
            }

            Section("How it works") {
                VStack(alignment: .leading, spacing: VITASpacing.sm) {
                    infoRow("1", "Tap \"Scan My Face\" in the Skin Audit tab")
                    infoRow("2", "VITA uploads your selfie to PerfectCorp's servers (HIPAA/GDPR compliant)")
                    infoRow("3", "AI analyses 9 skin concerns — acne, dark circles, redness, oiliness, and more")
                    infoRow("4", "Results are stored locally and fed to VITA's AI for cross-domain reasoning")
                }
                .padding(.vertical, VITASpacing.xs)
            }
        }
        .navigationTitle("Skin Analysis API")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func infoRow(_ step: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: VITASpacing.sm) {
            Text(step)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(VITAColors.teal)
                .clipShape(Circle())
            Text(text)
                .font(VITATypography.caption)
                .foregroundStyle(VITAColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
