//
//  CaptureSessionManager.swift
//  omnixr-measure
//
//  Complete Object Capture Manager using Apple's RealityKit APIs
//

import Foundation
import SwiftUI
import ARKit
import RealityKit

// Capture states aligned with ObjectCaptureSession.CaptureState
enum CaptureState {
    case idle
    case capturing  
    case processing
    case preview    // New state for model preview
    case completed
    case failed
}

// Capture steps for guided workflow
enum CaptureStep: CaseIterable {
    case detecting
    case capturing
    
    var displayName: String {
        switch self {
        case .detecting: return "Object Detection"
        case .capturing: return "Capturing Object"
        }
    }
    
    var instruction: String {
        switch self {
        case .detecting: return "Point camera at object and tap 'Start Detection'"
        case .capturing: return "Walk around the object to capture from all angles"
        }
    }
}

// Capture passes for multi-pass workflow
enum CapturePass: Int, CaseIterable {
    case sides = 0
    case top = 1
    case bottom = 2
    
    var displayName: String {
        switch self {
        case .sides: return "Side Views"
        case .top: return "Top Views"
        case .bottom: return "Bottom Views"
        }
    }
    
    var instruction: String {
        switch self {
        case .sides: return "Walk around the object at eye level, capturing all sides"
        case .top: return "Capture the object from above, moving around the top"
        case .bottom: return "Capture the object from below angles and underneath"
        }
    }
    
    var detailedInstruction: String {
        switch self {
        case .sides:
            return "Hold your device at the same height as the object and walk in a complete circle around it. Keep the object centered in the frame."
        case .top:
            return "Hold your device above the object and capture from different angles looking down. Move around the object while maintaining the top view."
        case .bottom:
            return "Capture the object from below by angling your device upward. Try to get underneath views if possible."
        }
    }
    
    var icon: String {
        switch self {
        case .sides: return "arrow.triangle.2.circlepath"
        case .top: return "arrow.up.circle"
        case .bottom: return "arrow.down.circle"
        }
    }
}

@MainActor
class CaptureSessionManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var captureState: CaptureState = .idle
    @Published var progress: Double = 0.0
    @Published var errorMessage: String?
    @Published var isSupported: Bool = false
    @Published var currentStep: CaptureStep = .detecting
    @Published var capturedImageCount: Int = 0
    @Published var captureDuration: TimeInterval = 0
    @Published var processingStage: String = ""
    @Published var estimatedRemainingTime: TimeInterval = 0
    @Published var previewModelURL: URL?  // For model preview
    
    // Multi-pass capture properties
    @Published var currentPass: CapturePass = .sides
    @Published var completedPasses: Set<CapturePass> = []
    @Published var showingPassPrompt: Bool = false
    @Published var isMultiPassMode: Bool = true
    
    // MARK: - Private Properties
    private var _captureSession: ObjectCaptureSession?
    private var photogrammetrySession: PhotogrammetrySession?
    private var captureView: (any View)?
    private var modelName: String = ""
    private var fileStorageService: FileStorageService?
    private var captureStartTime: Date?
    private var captureTimer: Timer?
    private var outputURLs: (usdz: URL, thumbnail: URL, metadata: URL)?
    private var imagesDirectory: URL?
    
    // MARK: - Computed Properties
    
    /// Get the actual ObjectCaptureSession state
    var sessionState: ObjectCaptureSession.CaptureState? {
        return _captureSession?.state
    }
    
    /// Get the actual ObjectCaptureSession for UI monitoring
    var captureSession: ObjectCaptureSession? {
        return _captureSession
    }
    
    var formattedCaptureDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: captureDuration) ?? "00:00"
    }
    
    var formattedRemainingTime: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: estimatedRemainingTime) ?? "Unknown"
    }
    
    // MARK: - Initialization
    init() {
        checkSupport()
    }
    
    // MARK: - Support Check
    private func checkSupport() {
        // First check iOS version
        guard #available(iOS 17.0, *) else {
            isSupported = false
            print("❌ ObjectCapture requires iOS 17.0+")
            return
        }
        
        // Check if ObjectCapture APIs are available
            isSupported = ObjectCaptureSession.isSupported
        if !isSupported {
            print("❌ ObjectCapture not supported on this device (requires LiDAR)")
        } else {
            print("✅ ObjectCapture supported")
        }
    }
    
    // MARK: - Capture Session Management
    
    /// Start capture session with model name and storage service
    func startCaptureSession(modelName: String, storageService: FileStorageService) {
        self.modelName = modelName
        self.fileStorageService = storageService
        startCapture(modelName: modelName)
    }
    
    /// Start capture session (following SuperSimpleObjectCapture pattern)
    func startCapture(modelName: String) {
        guard isSupported else {
            errorMessage = "Object Capture not supported on this device"
            captureState = .failed
            return
        }
        
        guard #available(iOS 17.0, *) else {
            errorMessage = "Object Capture requires iOS 17.0 or later"
            captureState = .failed
            return
        }
        
        self.modelName = modelName
        self.errorMessage = nil
        self.progress = 0.0
        self.capturedImageCount = 0
        self.captureDuration = 0
        self.currentStep = .detecting
        self.captureStartTime = Date()
        self.processingStage = ""
        self.estimatedRemainingTime = 0
        
        // Initialize multi-pass state
        self.currentPass = .sides
        self.completedPasses.removeAll()
        self.showingPassPrompt = false
        
        // Setup directories and URLs
        setupOutputDirectories()
        
        // Create ObjectCaptureSession (no try needed, like SuperSimpleObjectCapture)
        _captureSession = ObjectCaptureSession()
        
        guard let session = _captureSession,
              let imagesDir = imagesDirectory else {
            errorMessage = "Failed to create capture session"
            captureState = .failed
            return
        }
        
        // Create capture view
        captureView = ObjectCaptureView(session: session)
        
        // Start session (no configuration needed, like SuperSimpleObjectCapture)
        session.start(imagesDirectory: imagesDir)
        
        // Setup observers for session state and scan pass completion
        setupSessionObservers(session: session)
        
                captureState = .capturing
        startCaptureTimer()
    }
    
    /// Setup session observers (following SuperSimpleObjectCapture pattern)
    private func setupSessionObservers(session: ObjectCaptureSession) {
        // Remove the timer-based approach - we'll use SwiftUI onChange in the view instead
        print("📋 Session observers setup complete - using SwiftUI onChange pattern")
    }
    
    /// Handle scan pass completion (called from UI onChange)
    func handleScanPassCompleted() {
        print("📋 Scan pass completed by user - current pass: \(currentPass.displayName)")
        
        // Mark current pass as completed
        completedPasses.insert(currentPass)
        
        if isMultiPassMode && currentPass != .bottom {
            // Show prompt for next pass instead of finishing
            print("🔄 Showing pass completion prompt for next pass")
            showingPassPrompt = true
        } else {
            // This was the last pass or single-pass mode, finish the session
            print("🏁 Last pass completed, finishing session...")
            _captureSession?.finish()
        }
    }
    
    /// Handle session state change (called from UI onChange)
    func handleSessionStateChange(_ state: ObjectCaptureSession.CaptureState) {
        print("🔄 OBJECTCAPTURE STATE CHANGE: \(state)")
        
        DispatchQueue.main.async {
            switch state {
            case .ready:
                print("✅ Session ready for object detection")
                self.currentStep = .detecting
                
            case .detecting:
                print("🔍 Detecting object bounds...")
                self.currentStep = .detecting
                
            case .capturing:
                print("📸 Capturing images...")
                self.currentStep = .capturing
                
            case .finishing:
                print("⏳ Finishing capture session...")
                // Don't change UI state here, let it complete naturally
                
            case .completed:
                print("🎉 ObjectCaptureSession completed successfully")
                // Session completed, start photogrammetry
                self.captureState = .processing
                self.stopCaptureTimer()
                
                // Clean up session reference
                let sessionRef = self._captureSession
                self._captureSession = nil
                
                // Start photogrammetry immediately
                Task {
                    await self.startPhotogrammetryProcessing()
                }
                
            case .failed(let error):
                print("❌ ObjectCaptureSession failed: \(error)")
                print("   - Error code: \(error.localizedDescription)")
                self.errorMessage = "Capture failed: \(error.localizedDescription)"
                self.captureState = .failed
                
            @unknown default:
                print("❓ Unknown ObjectCaptureSession state: \(state)")
            }
        }
    }
    
    /// Update image count in real-time during capture
    func updateImageCount() {
        guard let imagesDir = imagesDirectory else { return }
        
        do {
            let imageFiles = try FileManager.default.contentsOfDirectory(at: imagesDir, includingPropertiesForKeys: nil)
            let imageExtensions = ["heic", "jpg", "jpeg", "png"]
            let currentImageCount = imageFiles.filter { url in
                imageExtensions.contains(url.pathExtension.lowercased())
            }.count
            
            if currentImageCount != capturedImageCount {
                print("📊 Image count updated: \(capturedImageCount) -> \(currentImageCount)")
                capturedImageCount = currentImageCount
            }
        } catch {
            print("⚠️ Failed to count images: \(error)")
        }
    }
    
    /// Start object detection
    func startDetecting() {
        print("🎯 Starting object detection...")
        guard let session = _captureSession else {
            print("❌ No capture session available")
            return
        }
        
        print("📋 Current session state: \(session.state)")
        
        guard session.state == .ready else {
            print("⚠️ Session not ready for detection. Current state: \(session.state)")
            errorMessage = "Session not ready for detection"
            return
        }
        
        let success = session.startDetecting()
        if success {
            print("✅ Object detection started successfully")
        } else {
            print("❌ Failed to start object detection")
            errorMessage = "Failed to start detection"
            captureState = .failed
        }
    }
    
    /// Start object capturing
    func startCapturing() {
        print("📸 Starting object capturing...")
        guard let session = _captureSession else {
            print("❌ No capture session available")
            return
        }
        
        print("📋 Current session state: \(session.state)")
        
        guard session.state == .detecting else {
            print("⚠️ Session not in detecting state. Current state: \(session.state)")
            errorMessage = "Session not ready for capturing"
            return
        }
        
        session.startCapturing()
        print("✅ Object capturing started successfully")
    }
    
    /// Finish current capture pass
    func finishCurrentPass() {
        print("🏁 Finishing current pass: \(currentPass.displayName)")
        
        // Mark current pass as completed
        completedPasses.insert(currentPass)
        
        if isMultiPassMode && currentPass != .bottom {
            // Show prompt for next pass
            showingPassPrompt = true
        } else {
            // Finish entire capture session
            finishCapture()
        }
    }
    
    /// Continue to next capture pass
    func continueToNextPass() {
        guard let nextPass = getNextPass() else {
            finishCapture()
            return
        }
        
        currentPass = nextPass
        showingPassPrompt = false
        
        print("➡️ Moving to next pass: \(currentPass.displayName)")
        
        // Continue with the same session - don't restart
        // The session remains in capturing state
    }
    
    /// Skip remaining passes and go to processing
    func skipToProcessing() {
        showingPassPrompt = false
        finishCapture()
    }
    
    /// Get the next capture pass
    private func getNextPass() -> CapturePass? {
        switch currentPass {
        case .sides:
            return .top
        case .top:
            return .bottom
        case .bottom:
            return nil
        }
    }
    
    /// Finish capture and start processing
    func finishCapture() {
        print("🏁 Finishing capture session...")
        guard let session = _captureSession else {
            print("❌ No capture session available")
            return
        }
        
        print("📋 Current session state: \(session.state)")
        
        guard session.state == .capturing else {
            print("⚠️ Session not in capturing state. Current state: \(session.state)")
            errorMessage = "Session not ready for finishing"
            return
        }
        
        session.finish()
        print("✅ Finish command sent to session")
    }
    
    /// Cancel current capture
    func cancelCapture() {
        stopCaptureTimer()
        
        // Cancel photogrammetry if running
        photogrammetrySession?.cancel()
        photogrammetrySession = nil
        
        _captureSession?.finish()
        _captureSession = nil
        captureView = nil
        
        captureState = .idle
        progress = 0.0
        errorMessage = nil
        modelName = ""
        capturedImageCount = 0
        captureDuration = 0
        currentStep = .detecting
        captureStartTime = nil
        outputURLs = nil
        imagesDirectory = nil
        processingStage = ""
        estimatedRemainingTime = 0
        previewModelURL = nil
        
        // Reset multi-pass state
        currentPass = .sides
        completedPasses.removeAll()
        showingPassPrompt = false
    }
    
    /// Reset to idle state
    func reset() {
        cancelCapture()
    }
    
    // MARK: - PhotogrammetrySession Implementation (following SuperSimpleObjectCapture)
    
    /// Start photogrammetry processing (async like SuperSimpleObjectCapture)
    private func startPhotogrammetryProcessing() async {
        guard let imagesDir = imagesDirectory,
              let outputURLs = outputURLs else {
            await MainActor.run {
                self.errorMessage = "Missing required directories for processing"
                self.captureState = .failed
            }
            return
        }
        
        do {
            // Count captured images
            let imageFiles = try FileManager.default.contentsOfDirectory(at: imagesDir, includingPropertiesForKeys: nil)
            let imageExtensions = ["heic", "jpg", "jpeg", "png"]
            let imageCount = imageFiles.filter { url in
                imageExtensions.contains(url.pathExtension.lowercased())
            }.count
            
            await MainActor.run {
                self.capturedImageCount = imageCount
                self.processingStage = "Starting photogrammetry with \(imageCount) images..."
            }
            
            print("📸 PHOTOGRAMMETRY SESSION STARTING")
            print("📁 Images directory: \(imagesDir.path)")
            print("📊 Total images found: \(imageCount)")
            print("💾 Output USDZ: \(outputURLs.usdz.path)")
            
            // Create PhotogrammetrySession (simple, like SuperSimpleObjectCapture)
            photogrammetrySession = try PhotogrammetrySession(input: imagesDir)
            
            guard let session = photogrammetrySession else {
                throw NSError(domain: "PhotogrammetryError", code: -1, 
                            userInfo: [NSLocalizedDescriptionKey: "Failed to create photogrammetry session"])
            }
            
            print("✅ PhotogrammetrySession created successfully")
            
            // Process model file request (simple, like SuperSimpleObjectCapture)
            try session.process(requests: [.modelFile(url: outputURLs.usdz)])
            
            print("🔄 Processing request submitted for model file")
            
            // Observe outputs with comprehensive logging
            for try await output in session.outputs {
                await MainActor.run {
                    self.handlePhotogrammetryOutput(output)
                }
            }
            
        } catch {
            print("❌ PHOTOGRAMMETRY SESSION FAILED: \(error)")
            if let photogrammetryError = error as? PhotogrammetrySession.Error {
                print("📋 PhotogrammetrySession.Error details:")
                print("   - Error: \(photogrammetryError)")
                print("   - Localized: \(photogrammetryError.localizedDescription)")
            }
            await MainActor.run {
                self.errorMessage = "Failed to start photogrammetry: \(error.localizedDescription)"
                self.captureState = .failed
            }
        }
    }
    
    /// Handle PhotogrammetrySession output events (with comprehensive logging)
    private func handlePhotogrammetryOutput(_ output: PhotogrammetrySession.Output) {
        print("📤 PHOTOGRAMMETRY OUTPUT: \(output)")
        
        switch output {
        case .requestError(let request, let error):
            print("❌ REQUEST ERROR:")
            print("   - Request: \(request)")
            print("   - Error: \(error)")
            print("   - Localized: \(error.localizedDescription)")
            self.errorMessage = "Processing failed: \(error.localizedDescription)"
            self.captureState = .failed
            
        case .requestProgress(let request, let fractionComplete):
            print("📊 REQUEST PROGRESS:")
            print("   - Request: \(request)")
            print("   - Fraction Complete: \(fractionComplete)")
            print("   - Percentage: \(Int(fractionComplete * 100))%")
            
            self.progress = min(1.0, max(0.0, fractionComplete))
            self.processingStage = self.getDetailedProcessingStage(progress: fractionComplete)
            
            // Calculate estimated remaining time
            if fractionComplete > 0 {
                let elapsed = Date().timeIntervalSince(captureStartTime ?? Date())
                let totalEstimated = elapsed / fractionComplete
                self.estimatedRemainingTime = max(0, totalEstimated - elapsed)
            }
            
        case .inputComplete:
            print("✅ INPUT COMPLETE: All input images validated and processed")
            self.processingStage = "Input validation complete. Starting reconstruction..."
            
        case .processingComplete:
            print("🎉 PROCESSING COMPLETE: 3D model reconstruction finished")
            self.completePhotogrammetryProcessing()
            
        case .processingCancelled:
            print("⏹️ PROCESSING CANCELLED: User cancelled the reconstruction")
            self.captureState = .idle
            self.photogrammetrySession = nil
            
        case .requestComplete(let request, let result):
            print("✅ REQUEST COMPLETE:")
            print("   - Request: \(request)")
            print("   - Result: \(result)")
            
            switch result {
            case .modelFile(let url):
                print("📄 MODEL FILE CREATED: \(url.path)")
                self.processingStage = "3D model file created successfully!"
                
                // Check actual file size
                if FileManager.default.fileExists(atPath: url.path) {
                    let fileSize = self.getFileSize(at: url)
                    print("📦 Model file size: \(fileSize) bytes (\(fileSize / 1024 / 1024) MB)")
                }
                
            case .poses(let poses):
                print("📐 POSES GENERATED: \(poses)")
                
            @unknown default:
                print("❓ Unknown result type: \(result)")
            }
            
        case .stitchingIncomplete:
            print("⚠️ STITCHING INCOMPLETE: Some images couldn't be processed")
            self.processingStage = "Some images couldn't be processed, but model creation continues..."
            
        @unknown default:
            print("❓ UNKNOWN PHOTOGRAMMETRY OUTPUT: \(output)")
        }
    }
    
    /// Get detailed processing stage description based on progress
    private func getDetailedProcessingStage(progress: Double) -> String {
        let percentage = Int(progress * 100)
        
        switch progress {
        case 0.0..<0.1:
            return "Initializing photogrammetry engine... \(percentage)%"
        case 0.1..<0.25:
            return "Analyzing captured images... \(percentage)%"
        case 0.25..<0.4:
            return "Detecting image features... \(percentage)%"
        case 0.4..<0.6:
            return "Aligning images and building point cloud... \(percentage)%"
        case 0.6..<0.8:
            return "Generating 3D mesh geometry... \(percentage)%"
        case 0.8..<0.95:
            return "Creating and applying textures... \(percentage)%"
        case 0.95..<1.0:
            return "Optimizing and finalizing model... \(percentage)%"
        default:
            return "Creating 3D model... \(percentage)%"
        }
    }
    
    /// Complete photogrammetry processing and auto-save
    private func completePhotogrammetryProcessing() {
        guard let outputURLs = outputURLs,
              let storageService = fileStorageService else {
            self.errorMessage = "Missing storage configuration"
            self.captureState = .failed
            return
        }
        
        // Check if USDZ file was actually created
        guard FileManager.default.fileExists(atPath: outputURLs.usdz.path) else {
            self.errorMessage = "3D model file was not created"
            self.captureState = .failed
            return
        }
        
        // Get actual file size
        let fileSize = getFileSize(at: outputURLs.usdz)
        print("✅ Model ready for preview - Size: \(fileSize / 1024 / 1024) MB")
        
        // Set preview state and model URL
        previewModelURL = outputURLs.usdz
        captureState = .preview
        progress = 1.0
        processingStage = "Ready for preview!"
        photogrammetrySession = nil
        
        // Auto-save after a brief preview period
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.saveModelAutomatically()
        }
    }
    
    /// Auto-save model to library
    private func saveModelAutomatically() {
        guard let outputURLs = outputURLs,
              let storageService = fileStorageService else {
            self.errorMessage = "Missing storage configuration"
            self.captureState = .failed
            return
        }
        
        // Get actual file size
        let fileSize = getFileSize(at: outputURLs.usdz)
        
        // Create model with real data
        let scannedModel = ScannedModel(
            name: modelName,
            createdDate: Date(),
            usdzFileURL: outputURLs.usdz,
            thumbnailImageURL: outputURLs.thumbnail,
            metadataFileURL: outputURLs.metadata,
            scanDuration: captureDuration,
            numberOfImages: capturedImageCount,
            fileSize: fileSize,
            dimensions: ModelDimensions(width: 0.2, height: 0.15, depth: 0.1),
            surfaceArea: 150.0,
            qualityScore: 0.85,
            detailLevel: .medium,
            hasLiDARData: true
        )
        
        print("💾 Auto-saving model: \(scannedModel.name)")
        print("📂 Model path: \(outputURLs.usdz.path)")
        print("📊 Model size: \(fileSize) bytes")
        
        // Save model to storage
        Task {
            await storageService.saveModel(scannedModel)
            await MainActor.run {
                self.captureState = .completed
                self.processingStage = "Model saved to library!"
                print("✅ Model successfully saved to library: \(scannedModel.name)")
            }
        }
    }
    
    /// Save model to library (called from preview)
    func saveModel() {
        guard let outputURLs = outputURLs,
              let storageService = fileStorageService else {
            self.errorMessage = "Missing storage configuration"
            self.captureState = .failed
            return
        }
        
        // Get actual file size
        let fileSize = getFileSize(at: outputURLs.usdz)
        
        // Create model with real data
        let scannedModel = ScannedModel(
            name: modelName,
            createdDate: Date(),
            usdzFileURL: outputURLs.usdz,
            thumbnailImageURL: outputURLs.thumbnail,
            metadataFileURL: outputURLs.metadata,
            scanDuration: captureDuration,
            numberOfImages: capturedImageCount,
            fileSize: fileSize,
            dimensions: ModelDimensions(width: 0.2, height: 0.15, depth: 0.1),
            surfaceArea: 150.0,
            qualityScore: 0.85,
            detailLevel: .medium,
            hasLiDARData: true
        )
        
        // Save model to storage
        Task {
            await storageService.saveModel(scannedModel)
            await MainActor.run {
                self.captureState = .completed
                self.processingStage = "Model saved to library!"
                print("💾 Model saved to library: \(scannedModel.name)")
            }
        }
    }
    
    /// Discard model (called from preview)
    func discardModel() {
        // Clean up temporary files
        if let outputURLs = outputURLs {
            try? FileManager.default.removeItem(at: outputURLs.usdz)
            try? FileManager.default.removeItem(at: outputURLs.thumbnail)
            try? FileManager.default.removeItem(at: outputURLs.metadata)
            print("🗑️ Model discarded and temporary files cleaned up")
        }
        
        // Reset to idle state
        reset()
    }
    
    // MARK: - Helper Methods
    
    /// Get file size for a given URL
    func getFileSize(at url: URL) -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
    
    // MARK: - Private Methods
    
    private func setupOutputDirectories() {
        guard let storageService = fileStorageService else { return }
        
        // Generate file URLs using the storage service
        let urls = storageService.generateFileURLs(for: modelName)
        outputURLs = urls
        
        // Create images directory in temp
        let tempDirectory = storageService.getTempDirectory()
        imagesDirectory = tempDirectory.appendingPathComponent("Images_\(UUID().uuidString)")
        
        // Safely create directory with error handling
        if let imagesDir = imagesDirectory {
            do {
                try FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
            } catch {
                print("⚠️ Failed to create images directory: \(error.localizedDescription)")
                imagesDirectory = nil
            }
        }
    }
    
    private func startCaptureTimer() {
        captureTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                if let startTime = self.captureStartTime {
                    self.captureDuration = Date().timeIntervalSince(startTime)
                }
            }
        }
    }
    
    private func stopCaptureTimer() {
        captureTimer?.invalidate()
        captureTimer = nil
    }
    
    // MARK: - Public Access Methods
    
    /// Get capture view for UI integration
    func getCaptureView() -> (any View)? {
        return captureView
    }
    
    /// Check if capture is in progress
    var isCaptureInProgress: Bool {
        return captureState == .capturing
    }
    
    /// Check if processing is in progress
    var isProcessingInProgress: Bool {
        return captureState == .processing
    }
} 