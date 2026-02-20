import SwiftUI
import UIKit
import VITADesignSystem

struct FaceHeatmapView: View {
    let conditions: [PerfectCorpService.SkinCondition]
    let capturedImage: UIImage?
    let apiBaseImageURL: String?

    @State private var isPreviewPresented = false
    @State private var isSharePresented = false
    @State private var shareItems: [Any] = []
    @State private var isPreparingDownload = false
    @State private var downloadError: String?

    private var baseImageURL: URL? {
        guard let raw = apiBaseImageURL else { return nil }
        return URL(string: raw)
    }

    private var overlayMaskURLs: [URL] {
        var seen = Set<String>()
        return conditions
            .compactMap(\.overlayMaskURL)
            .compactMap { raw in
                guard let url = URL(string: raw) else { return nil }
                guard seen.insert(url.absoluteString).inserted else { return nil }
                return url
            }
    }

    var body: some View {
        VStack(spacing: VITASpacing.xs) {
            Text("Problem Overlay")
                .font(VITATypography.caption)
                .foregroundStyle(VITAColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            GeometryReader { _ in
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(VITAColors.tertiaryBackground)

                    if let image = capturedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                    } else if let fallbackBase = baseImageURL {
                        remoteImage(url: fallbackBase, opacity: 1.0)
                    }

                    // Optional faint API base for better alignment with returned masks.
                    if capturedImage != nil, let fallbackBase = baseImageURL {
                        remoteImage(url: fallbackBase, opacity: 0.20)
                    }

                    ForEach(overlayMaskURLs, id: \.absoluteString) { url in
                        remoteImage(url: url, opacity: 0.55)
                            .blendMode(.screen)
                    }

                    if capturedImage == nil && baseImageURL == nil {
                        VStack(spacing: 6) {
                            Image(systemName: "person.crop.square")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(VITAColors.textTertiary)
                            Text("No base image available")
                                .font(VITATypography.caption2)
                                .foregroundStyle(VITAColors.textTertiary)
                        }
                    } else if overlayMaskURLs.isEmpty {
                        Text("No mask overlays returned by API")
                            .font(VITATypography.caption2)
                            .foregroundStyle(VITAColors.textTertiary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(.top, 6)
                            .frame(maxHeight: .infinity, alignment: .top)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .contentShape(Rectangle())
                .onTapGesture {
                    guard hasPreviewContent else { return }
                    isPreviewPresented = true
                }
            }

            Text(overlayMaskURLs.isEmpty ? "API mask overlays unavailable for this scan." : "Layered API masks show exact affected regions.")
                .font(VITATypography.caption2)
                .foregroundStyle(VITAColors.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(VITASpacing.cardPadding)
        .background(VITAColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
        .fullScreenCover(isPresented: $isPreviewPresented) {
            NavigationStack {
                ZStack {
                    Color.black.ignoresSafeArea()

                    stackedOverlayImage(showEmptyState: true)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 20)
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") { isPreviewPresented = false }
                            .foregroundStyle(.white)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            downloadStackedPreview()
                        } label: {
                            if isPreparingDownload {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Download")
                            }
                        }
                        .disabled(!hasPreviewContent || isPreparingDownload)
                        .foregroundStyle(.white)
                    }
                }
            }
            .sheet(isPresented: $isSharePresented) {
                OverlayShareSheet(items: shareItems)
            }
            .alert("Download failed", isPresented: Binding(
                get: { downloadError != nil },
                set: { if !$0 { downloadError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(downloadError ?? "Could not download image.")
            }
        }
    }

    @ViewBuilder
    private func stackedOverlayImage(showEmptyState: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(VITAColors.tertiaryBackground)

            if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else if let fallbackBase = baseImageURL {
                remoteImage(url: fallbackBase, opacity: 1.0)
            }

            if capturedImage != nil, let fallbackBase = baseImageURL {
                remoteImage(url: fallbackBase, opacity: 0.20)
            }

            ForEach(overlayMaskURLs, id: \.absoluteString) { url in
                remoteImage(url: url, opacity: 0.55)
                    .blendMode(.screen)
            }

            if showEmptyState, capturedImage == nil && baseImageURL == nil {
                VStack(spacing: 6) {
                    Image(systemName: "person.crop.square")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(VITAColors.textTertiary)
                    Text("No base image available")
                        .font(VITATypography.caption2)
                        .foregroundStyle(VITAColors.textTertiary)
                }
            } else if showEmptyState, overlayMaskURLs.isEmpty {
                Text("No mask overlays returned by API")
                    .font(VITATypography.caption2)
                    .foregroundStyle(VITAColors.textTertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 6)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func remoteImage(url: URL, opacity: Double) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .opacity(opacity)
            default:
                EmptyView()
            }
        }
    }

    private var hasPreviewContent: Bool {
        capturedImage != nil || baseImageURL != nil || !overlayMaskURLs.isEmpty
    }

    private func downloadStackedPreview() {
        guard hasPreviewContent else { return }
        Task {
            await MainActor.run {
                isPreparingDownload = true
                downloadError = nil
            }
            do {
                let fileURL = try await stackedCompositeFileURL()
                await MainActor.run {
                    shareItems = [fileURL]
                    isSharePresented = true
                    isPreparingDownload = false
                }
            } catch {
                await MainActor.run {
                    downloadError = error.localizedDescription
                    isPreparingDownload = false
                }
            }
        }
    }

    private func stackedCompositeFileURL() async throws -> URL {
        let remoteBaseImage: UIImage?
        if let url = baseImageURL {
            remoteBaseImage = try await fetchImage(from: url)
        } else {
            remoteBaseImage = nil
        }

        var maskImages: [UIImage] = []
        try await withThrowingTaskGroup(of: UIImage?.self) { group in
            for url in overlayMaskURLs {
                group.addTask {
                    try? await fetchImage(from: url)
                }
            }
            for try await maybeImage in group {
                if let image = maybeImage {
                    maskImages.append(image)
                }
            }
        }

        guard capturedImage != nil || remoteBaseImage != nil || !maskImages.isEmpty else {
            throw NSError(
                domain: "FaceOverlay",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "No image data available to download."]
            )
        }

        let canvasSize = capturedImage?.size ?? remoteBaseImage?.size ?? maskImages.first?.size ?? CGSize(width: 1080, height: 1080)
        let canvasRect = CGRect(origin: .zero, size: canvasSize)

        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        let composite = renderer.image { ctx in
            UIColor.clear.setFill()
            ctx.fill(canvasRect)

            if let base = capturedImage {
                let rect = aspectFitRect(for: base.size, in: canvasRect)
                base.draw(in: rect)
            } else if let remoteBaseImage {
                let rect = aspectFitRect(for: remoteBaseImage.size, in: canvasRect)
                remoteBaseImage.draw(in: rect)
            }

            if capturedImage != nil, let remoteBaseImage {
                let rect = aspectFitRect(for: remoteBaseImage.size, in: canvasRect)
                remoteBaseImage.draw(in: rect, blendMode: .normal, alpha: 0.20)
            }

            for mask in maskImages {
                let rect = aspectFitRect(for: mask.size, in: canvasRect)
                mask.draw(in: rect, blendMode: .screen, alpha: 0.55)
            }
        }

        guard let png = composite.pngData() else {
            throw NSError(
                domain: "FaceOverlay",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Could not render composite image."]
            )
        }
        return try writeTempImageFile(data: png, ext: "png")
    }

    private func fetchImage(from url: URL) async throws -> UIImage {
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let image = UIImage(data: data) else {
            throw NSError(
                domain: "FaceOverlay",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Downloaded image was invalid."]
            )
        }
        return image
    }

    private func aspectFitRect(for imageSize: CGSize, in container: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return container }
        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: container.midX - size.width / 2,
            y: container.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    private func writeTempImageFile(data: Data, ext: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
        let fileURL = directory.appendingPathComponent("vita-overlay-\(UUID().uuidString).\(ext)")
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }
}

private struct OverlayShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
