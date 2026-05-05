// CameraManager.swift
// Info.plist: NSCameraUsageDescription → "NEXO necesita la cámara para identificar residuos."

import AVFoundation
import SwiftUI
import Vision
import Combine

class _CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> _CameraPreviewUIView {
        let view = _CameraPreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }
    func updateUIView(_ uiView: _CameraPreviewUIView, context: Context) {}
}

final class CameraManager: NSObject, ObservableObject {
    @Published var detectedMaterial: NEXOMaterial? = nil
    @Published var isAnalyzing     : Bool          = false
    @Published var errorMessage    : String?       = nil

    let session     = AVCaptureSession()
    private let out = AVCapturePhotoOutput()

    override init() {
        super.init()
        configureSession()
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input  = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            DispatchQueue.main.async { self.errorMessage = "No se pudo acceder a la cámara." }
            session.commitConfiguration(); return
        }
        session.addInput(input)
        if session.canAddOutput(out) { session.addOutput(out) }
        session.commitConfiguration()
    }

    func start() { DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() } }
    func stop()  { DispatchQueue.global(qos: .userInitiated).async { self.session.stopRunning()  } }

    func capture() {
        guard !isAnalyzing else { return }
        DispatchQueue.main.async { self.isAnalyzing = true; self.errorMessage = nil }
        out.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }

    private func analyze(data: Data) {
        guard let ci = CIImage(data: data) else {
            DispatchQueue.main.async { self.isAnalyzing = false }; return
        }
        let request = VNClassifyImageRequest { [weak self] req, _ in
            guard let self else { return }
            let results = req.results as? [VNClassificationObservation] ?? []
            var found: NEXOMaterial? = nil
            for obs in results.prefix(15) {
                if let mat = NEXOMaterial.from(visionLabel: obs.identifier) { found = mat; break }
            }
            DispatchQueue.main.async {
                self.isAnalyzing = false
                if let found { self.detectedMaterial = found }
                else { self.errorMessage = "No reconocí este residuo. Acércate más o mejora la iluminación." }
            }
        }
        DispatchQueue.global(qos: .userInitiated).async {
            try? VNImageRequestHandler(ciImage: ci, options: [:]).perform([request])
        }
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation() else {
            DispatchQueue.main.async { self.isAnalyzing = false }; return
        }
        analyze(data: data)
    }
}
