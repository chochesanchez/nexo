// CameraManager.swift
// Usa VNCoreMLRequest con el modelo NexoClass1 entrenado en Create ML
// en paralelo con VNRecognizeTextRequest para lectura de etiquetas.

// CameraManager.swift
// Pipeline DUAL:
//   • YOLO (YOLONexo.mlpackage) → corre en VIDEO, da bounding boxes en tiempo real
//   • NexoClass1 (tu modelo)    → corre en FOTO al confirmar, da la clasificación final
//   • VNRecognizeTextRequest    → corre en FOTO, lee etiquetas y símbolos
//
// ¿Por qué los dos?
//   YOLO es rápido y visual pero genérico.
//   NexoClass1 fue entrenado con tus datos específicos → más preciso para tus 6 clases.
//   YOLO muestra el box, NexoClass1 decide qué material es realmente.

import AVFoundation
import Vision
import CoreML
import SwiftUI
import Combine

// MARK: - YOLODetection

struct YOLODetection: Identifiable {
    let id          = UUID()
    let classKey    : String
    let confidence  : Float
    /// Coordenadas Vision normalizadas (0–1), origin bottom-left, y-up.
    /// BoundingBoxView convierte a coordenadas de pantalla.
    let boundingBox : CGRect
    let material    : NEXOMaterial?

    var displayName    : String { material?.displayName ?? classKey }
    var confidencePct  : Int    { Int(confidence * 100) }
    var isHighConfidence: Bool  { confidence >= 0.55 }
}

// MARK: - CameraPreview

class _CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> _CameraPreviewUIView {
        let v = _CameraPreviewUIView()
        v.previewLayer.session      = session
        v.previewLayer.videoGravity = .resizeAspectFill
        return v
    }
    func updateUIView(_ uiView: _CameraPreviewUIView, context: Context) {}
}

// MARK: - CameraManager

final class CameraManager: NSObject, ObservableObject {

    // ── YOLO: detecciones en tiempo real (video) ───────────────────────────
    @Published var detections   : [YOLODetection] = []
    @Published var topDetection : YOLODetection?  = nil

    // ── NexoClass1: resultado final (foto al confirmar) ────────────────────
    @Published var detectedMaterial  : NEXOMaterial? = nil
    @Published var detectedOCRText   : String?       = nil
    @Published var capturedImageData : Data?          = nil
    @Published var isAnalyzing       : Bool           = false
    @Published var errorMessage      : String?        = nil

    // ── AVFoundation ───────────────────────────────────────────────────────
    let session   = AVCaptureSession()
    private let photoOut = AVCapturePhotoOutput()
    private let videoOut = AVCaptureVideoDataOutput()

    private let yoloQueue    = DispatchQueue(label: "nexo.yolo",     qos: .userInteractive)
    private let classifyQueue = DispatchQueue(label: "nexo.classify", qos: .userInitiated)
    private let ocrQueue      = DispatchQueue(label: "nexo.ocr",      qos: .utility)

    // ── Los dos modelos ────────────────────────────────────────────────────
    /// Modelo YOLO — corre en video, da bounding boxes.
    /// Cuando no está disponible, usa NexoClass1 en su lugar (boxes sintéticos).
    private var yoloVNModel     : VNCoreMLModel?
    private var yoloAvailable   = false

    /// Tu modelo Create ML — corre en foto, da la clasificación final.
    private var classifyVNModel : VNCoreMLModel?

    // ── Rate limiting ──────────────────────────────────────────────────────
    private var frameCounter = 0
    private let frameSkip    = 8      // 1 de cada 8 frames ≈ 3-4 inferencias/seg a 30fps
    private var isInference  = false

    override init() {
        super.init()
        loadModels()
        configureSession()
    }

    // MARK: - Cargar ambos modelos

    private func loadModels() {

        // ── Modelo 1: YOLO para video ──────────────────────────────────────
        if let model = try? YOLONexo(configuration: MLModelConfiguration()).model,
            let vn    = try? VNCoreMLModel(for: model) {
             yoloVNModel   = vn
             yoloAvailable = true
             print("[NEXO] YOLO cargado ✓ — bounding boxes reales activos")
         }

        // ── Modelo 2: NexoClass1 para foto (siempre disponible) ────────────
        if let model = try? NexoClass1(configuration: MLModelConfiguration()).model,
           let vn    = try? VNCoreMLModel(for: model) {
            classifyVNModel = vn
            print("[NEXO] NexoClass1 cargado ✓")
        }

        // Si YOLO no está disponible, NexoClass1 también hace el trabajo de video
        // (sin bounding boxes reales, pero el chip de detección funciona igual)
        if yoloVNModel == nil {
            yoloVNModel = classifyVNModel
            print("[NEXO] YOLO no encontrado — usando NexoClass1 para video (boxes sintéticos)")
        }
    }

    // MARK: - Sesión

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .hd1280x720

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                  for: .video, position: .back),
            let input  = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            DispatchQueue.main.async { self.errorMessage = "No se pudo acceder a la cámara." }
            session.commitConfiguration(); return
        }
        session.addInput(input)

        // Video output → YOLO por frame
        videoOut.setSampleBufferDelegate(self, queue: yoloQueue)
        videoOut.alwaysDiscardsLateVideoFrames = true
        videoOut.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
        if session.canAddOutput(videoOut) { session.addOutput(videoOut) }

        // Orientación portrait para que los boxes coincidan con la preview
        if let conn = videoOut.connection(with: .video) {
            conn.videoRotationAngle = 90
        }

        // Photo output → NexoClass1 + OCR al confirmar
        if session.canAddOutput(photoOut) { session.addOutput(photoOut) }

        session.commitConfiguration()
    }

    func start() { DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() } }
    func stop()  { DispatchQueue.global(qos: .userInitiated).async { self.session.stopRunning()  } }

    // MARK: - Confirmar → foto → NexoClass1 + OCR

    /// El usuario toca el botón de confirmación.
    /// YOLO ya mostró el box en pantalla.
    /// Ahora NexoClass1 da la clasificación final para FichaView.
    func capture() {
        guard !isAnalyzing else { return }
        DispatchQueue.main.async { self.isAnalyzing = true; self.errorMessage = nil }
        photoOut.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }

    // MARK: - Pipeline YOLO (video, frame a frame)

    private func runYOLO(on pixelBuffer: CVPixelBuffer) {
        guard let model = yoloVNModel, !isInference, !isAnalyzing else { return }
        isInference = true

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: .right,
                                            options: [:])
        let request = VNCoreMLRequest(model: model) { [weak self] req, _ in
            defer { self?.isInference = false }
            guard let self else { return }
            self.handleYOLOResults(req.results)
        }
        request.imageCropAndScaleOption = yoloAvailable ? .scaleFill : .centerCrop
        try? handler.perform([request])
    }

    private func handleYOLOResults(_ results: [VNObservation]?) {
        guard let results else {
            DispatchQueue.main.async { self.detections = []; self.topDetection = nil }
            return
        }

        // ── Con YOLO real: VNRecognizedObjectObservation → bounding boxes exactos
        if yoloAvailable,
           let objectObs = results as? [VNRecognizedObjectObservation], !objectObs.isEmpty {
            let detected: [YOLODetection] = objectObs
                .filter { $0.confidence > 0.35 }
                .prefix(5)
                .compactMap { obs in
                    guard let label = obs.labels.first else { return nil }
                    return YOLODetection(
                        classKey   : label.identifier,
                        confidence : label.confidence,
                        boundingBox: obs.boundingBox,
                        material   : NEXOMaterial.from(visionLabel: label.identifier)
                    )
                }
            DispatchQueue.main.async {
                self.detections   = detected
                self.topDetection = detected.first
            }
        }

        // ── Sin YOLO (NexoClass1 en video): VNClassificationObservation → box sintético
        else if let classObs = results as? [VNClassificationObservation],
                let top = classObs.first, top.confidence > 0.45 {
            let syntheticBox = CGRect(x: 0.15, y: 0.15, width: 0.70, height: 0.70)
            let det = YOLODetection(
                classKey   : top.identifier,
                confidence : top.confidence,
                boundingBox: syntheticBox,
                material   : NEXOMaterial.from(visionLabel: top.identifier)
            )
            DispatchQueue.main.async {
                self.detections   = [det]
                self.topDetection = det
            }
        } else {
            DispatchQueue.main.async { self.detections = []; self.topDetection = nil }
        }
    }

    // MARK: - Pipeline NexoClass1 (foto al confirmar)

    private func runNexoClass1(on ciImage: CIImage) {
        guard let model = classifyVNModel else {
            // Si tampoco hay NexoClass1, usa lo que detectó YOLO
            DispatchQueue.main.async {
                self.detectedMaterial = self.topDetection?.material
                if self.detectedMaterial == nil {
                    self.errorMessage = "No se pudo clasificar. Intenta de nuevo."
                }
                // OCR aún no ha terminado, isAnalyzing se desactiva en runOCR
            }
            return
        }

        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        let request = VNCoreMLRequest(model: model) { [weak self] req, _ in
            guard let self else { return }
            let classObs = req.results as? [VNClassificationObservation] ?? []

            // NexoClass1 da la clase final — más confiable que YOLO para tus 6 categorías
            if let best = classObs.first, best.confidence > 0.40 {
                let material = NEXOMaterial.from(visionLabel: best.identifier)
                DispatchQueue.main.async {
                    self.detectedMaterial = material ?? self.topDetection?.material
                    if self.detectedMaterial == nil {
                        self.errorMessage = "No reconocí este residuo. Acércate más."
                    }
                }
            } else {
                // Confianza muy baja → fallback a lo que detectó YOLO
                DispatchQueue.main.async {
                    self.detectedMaterial = self.topDetection?.material
                    if self.detectedMaterial == nil {
                        self.errorMessage = "Iluminación insuficiente o residuo fuera de categoría."
                    }
                }
            }
        }
        request.imageCropAndScaleOption = .centerCrop
        classifyQueue.async { try? handler.perform([request]) }
    }

    // MARK: - OCR (foto al confirmar)

    private func runOCR(on ciImage: CIImage) {
        let request = VNRecognizeTextRequest { [weak self] req, _ in
            guard let self else { return }
            let strings = (req.results as? [VNRecognizedTextObservation] ?? [])
                .compactMap { obs -> String? in
                    guard let top = obs.topCandidates(1).first, top.confidence > 0.5 else { return nil }
                    return top.string
                }
            let fullText = strings.joined(separator: " ").uppercased()
            let keywords = ["PET","HDPE","LDPE","PP","PS","PVC",
                            "LI-ION","LI-PO","MAH","RECHARGEABLE","RECARGABLE",
                            "COMPOSTABLE","BIODEGRADABLE","RECICLABLE",
                            "1","2","3","4","5","6","7"]
            let found = keywords.filter { fullText.contains($0) }
            DispatchQueue.main.async {
                if !found.isEmpty { self.detectedOCRText = found.joined(separator: ", ") }
                self.isAnalyzing = false   // ← pipeline completo
            }
        }
        request.recognitionLevel       = .accurate
        request.recognitionLanguages   = ["es-MX", "en-US"]
        request.usesLanguageCorrection = true
        ocrQueue.async {
            let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
            try? handler.perform([request])
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate — YOLO por frame

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        frameCounter += 1
        guard frameCounter % frameSkip == 0,
              !isAnalyzing,                              // pausa YOLO mientras clasifica foto
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        else { return }
        runYOLO(on: pixelBuffer)
    }
}

// MARK: - AVCapturePhotoCaptureDelegate — NexoClass1 + OCR sobre foto

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let ci   = CIImage(data: data) else {
            DispatchQueue.main.async { self.isAnalyzing = false }
            return
        }
        DispatchQueue.main.async { self.capturedImageData = data }

        // Corre NexoClass1 + OCR en paralelo sobre la misma foto
        runNexoClass1(on: ci)
        runOCR(on: ci)
        // isAnalyzing = false lo pone runOCR cuando termina (es el más lento)
    }
}
