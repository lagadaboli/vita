import SwiftUI
import UIKit

/// Wraps `UIImagePickerController` for use in SwiftUI.
/// Supports both the front camera (default) and photo library.
struct CameraPickerView: UIViewControllerRepresentable {

    enum Source {
        case camera
        case photoLibrary
    }

    let source: Source
    let onCapture: (UIImage) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = false

        switch source {
        case .camera:
            picker.sourceType = .camera
            picker.cameraDevice = .front       // selfie mode
            picker.cameraCaptureMode = .photo
        case .photoLibrary:
            picker.sourceType = .photoLibrary
        }

        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    // MARK: - Coordinator

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onCapture: (UIImage) -> Void
        private let onCancel: () -> Void

        init(onCapture: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onCancel = onCancel
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            } else {
                onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }

    /// Returns true if the camera is available on this device.
    static var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }
}
