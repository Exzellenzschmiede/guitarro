import AVFoundation
import HandCoach
import SwiftUI
import UIKit

/// Live camera preview backed by `AVCaptureVideoPreviewLayer`, kept upright by the session.
struct CameraPreview: UIViewRepresentable {
    let session: CameraSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session.captureSession
        view.previewLayer.videoGravity = .resizeAspect
        view.session = session
        session.attach(previewLayer: view.previewLayer)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        weak var session: CameraSession?

        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

        override func layoutSubviews() {
            super.layoutSubviews()
            guard let session, let connection = previewLayer.connection else { return }
            let angle = session.previewRotationAngle
            if connection.videoRotationAngle != angle, connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
        }
    }
}
