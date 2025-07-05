//
//  ObjectCaptureWorkflowView.swift
//  omnixr-measure
//
//  Created by phones luxury on 02/07/2025.
//

import SwiftUI
import AVFoundation
import ARKit
#if canImport(UIKit)
import UIKit
#endif


/// Complete workflow view for Object Capture using Apple's photogrammetry APIs
/// Guides users through the multi-step scanning process
struct ObjectCaptureWorkflowView: View {
    
    @EnvironmentObject private var fileStorageService: FileStorageService
    @EnvironmentObject private var captureSessionManager: CaptureSessionManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var modelName = ""
    @State private var showingNameInput = true
    @State private var showingCameraPermissionDenied = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()
                
                // Content based on capture state
                switch captureSessionManager.captureState {
                case .idle:
                    setupView
                
                case .capturing:
                    captureView
                case .processing:
                    processingView
                case .preview:
                    previewView
                case .completed:
                    completedView
                case .failed:
                    failedView
                }
            }
            .navigationTitle("3D Object Capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        captureSessionManager.cancelCapture()
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .sheet(isPresented: $showingNameInput) {
            nameInputView
        }
        .sheet(isPresented: $captureSessionManager.showingPassPrompt) {
            passPromptView
        }
        .alert("Camera Access Required", isPresented: $showingCameraPermissionDenied) {
            Button("Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("Cancel") {
                dismiss()
            }
        } message: {
            Text("This app needs camera access to scan 3D objects. Please enable camera access in Settings.")
        }
        .onChange(of: captureSessionManager.captureSession?.userCompletedScanPass) { _, newValue in
            if let newValue, newValue {
                print("🎯 UI detected scan pass completion")
                captureSessionManager.handleScanPassCompleted()
            }
        }
        .onChange(of: captureSessionManager.captureSession?.state) { _, newValue in
            if let newValue {
                print("🎯 UI detected state change: \(newValue)")
                captureSessionManager.handleSessionStateChange(newValue)
            }
        }
        .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
            // Update image count during capture
            if captureSessionManager.captureState == .capturing {
                captureSessionManager.updateImageCount()
            }
        }
    }
    
    // MARK: - Setup View
    
    private var setupView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "viewfinder.circle")
                    .font(.system(size: 64))
                    .foregroundColor(.white)
                
                Text("Ready to Scan")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Follow the guided steps to capture your object from all angles")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            Button {
                startCapture()
            } label: {
                Text("Start Scanning")
                    .font(.headline)
                    .foregroundColor(.black)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Name Input View
    
    private var nameInputView: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: "cube.transparent")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text("Name Your 3D Model")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Give your scanned object a memorable name")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                TextField("Model name", text: $modelName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("New Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Continue") {
                        showingNameInput = false
                    }
                    .disabled(modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Pass Prompt View
    
    private var passPromptView: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: captureSessionManager.currentPass.icon)
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text("Great Progress!")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("You've completed the \(captureSessionManager.currentPass.displayName) pass")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Show next pass info if available
                if let nextPass = getNextPass() {
                    VStack(spacing: 12) {
                        Text("Continue with \(nextPass.displayName)?")
                            .font(.headline)
                        
                        Text(nextPass.detailedInstruction)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // Progress indicator
                VStack(spacing: 8) {
                    Text("Capture Progress")
                        .font(.headline)
                    
                    HStack(spacing: 16) {
                        ForEach(CapturePass.allCases, id: \.self) { pass in
                            VStack(spacing: 4) {
                                Image(systemName: pass.icon)
                                    .font(.title3)
                                    .foregroundColor(
                                        captureSessionManager.completedPasses.contains(pass) ? .green :
                                        pass == captureSessionManager.currentPass ? .blue : .gray
                                    )
                                
                                Text(pass.displayName)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 12) {
                    if getNextPass() != nil {
                        Button("Continue to Next Pass") {
                            captureSessionManager.continueToNextPass()
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    
                    Button("Process Model Now") {
                        captureSessionManager.skipToProcessing()
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(12)
                }
            }
            .padding()
            .navigationTitle("Capture Pass Complete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Process") {
                        captureSessionManager.skipToProcessing()
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
    
    // MARK: - Preparing View
    
    private var preparingView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
            
            Text("Preparing Camera...")
                .font(.headline)
                .foregroundColor(.white)
            
            Spacer()
        }
    }
    
    // MARK: - Capture View
    
    private var captureView: some View {
        ZStack {
            // Real ObjectCapture View
            if let realCaptureView = captureSessionManager.getCaptureView() {
                AnyView(realCaptureView)
                    .ignoresSafeArea()
            } else {
                // Fallback if capture view is not ready
                Color.black
                    .ignoresSafeArea()
                    .overlay {
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                            
                            Text("Initializing Camera...")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
            }
            
            // Overlay UI
            VStack {
                // Top instruction overlay
                VStack(spacing: 8) {
                    // Current pass indicator
                    HStack(spacing: 8) {
                        Image(systemName: captureSessionManager.currentPass.icon)
                            .font(.title3)
                            .foregroundColor(.blue)
                        
                        Text(captureSessionManager.currentPass.displayName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(8)
                    
                    Text(getStepDisplayName())
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                    
                    Text(getStepInstruction())
                        .font(.body)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                }
                .padding(.top, 50)
                
                Spacer()
                
                // Bottom controls
                VStack(spacing: 16) {
                    // Progress indicator
                    HStack {
                        Text("Images: \(captureSessionManager.capturedImageCount)")
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text(captureSessionManager.formattedCaptureDuration)
                            .foregroundColor(.white)
                    }
                    
                    // Progress bar
                    ProgressView(value: max(0.0, min(1.0, captureSessionManager.progress)))
                        .progressViewStyle(LinearProgressViewStyle(tint: .white))
                    
                    // Control buttons
                    HStack(spacing: 16) {
                        // Cancel button
                        Button {
                            captureSessionManager.cancelCapture()
                            dismiss()
                        } label: {
                            Text("Cancel")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.red.opacity(0.8))
                                .cornerRadius(8)
                        }
                        
                        // Action button based on actual session state
                        Button {
                            if let sessionState = captureSessionManager.sessionState {
                                switch sessionState {
                                case .ready:
                                    captureSessionManager.startDetecting()
                                case .detecting:
                                    captureSessionManager.startCapturing()
                                default:
                                    break
                                }
                            }
                        } label: {
                            Text(getButtonText())
                                .font(.headline)
                                .foregroundColor(.black)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.white)
                                .cornerRadius(8)
                        }
                        
                        // Finish button (only show during capturing)
                        if captureSessionManager.sessionState == .capturing {
                            Button {
                                captureSessionManager.finishCurrentPass()
                            } label: {
                                Text("Finish Pass")
                                    .font(.headline)
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color.green.opacity(0.8))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding()
                .background(Color.black.opacity(0.8))
            }
        }
    }
    
    // MARK: - Processing View
    
    private var processingView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 20) {
                // Main progress indicator
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 8)
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .trim(from: 0, to: captureSessionManager.progress)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: captureSessionManager.progress)
                    
                    VStack(spacing: 4) {
                        Text("\(Int(captureSessionManager.progress * 100))%")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Complete")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                VStack(spacing: 12) {
                    Text("Creating 3D Model")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    // Display current processing stage
                    Text(captureSessionManager.processingStage.isEmpty ? "Processing images..." : captureSessionManager.processingStage)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Enhanced processing details
                    VStack(spacing: 12) {
                        // Image count - make this more prominent
                        HStack {
                            Image(systemName: "photo.stack.fill")
                                .font(.title3)
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text("Captured Images")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                Text("\(captureSessionManager.capturedImageCount) photos")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                        
                        // Capture duration
                        if captureSessionManager.captureDuration > 0 {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .font(.title3)
                                    .foregroundColor(.green)
                                VStack(alignment: .leading) {
                                    Text("Capture Duration")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                    Text(captureSessionManager.formattedCaptureDuration)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        // Estimated remaining time
                        if captureSessionManager.estimatedRemainingTime > 0 {
                            HStack {
                                Image(systemName: "timer")
                                    .font(.title3)
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading) {
                                    Text("Estimated Remaining")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                    Text(captureSessionManager.formattedRemainingTime)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        // Progress indicator
                        if captureSessionManager.progress > 0 {
                            HStack {
                                Image(systemName: "gearshape.fill")
                                    .font(.title3)
                                    .foregroundColor(.purple)
                                VStack(alignment: .leading) {
                                    Text("Processing Progress")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                    Text("\(Int(captureSessionManager.progress * 100))% complete")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Cancel button for processing
            Button {
                captureSessionManager.cancelCapture()
                dismiss()
            } label: {
                Text("Cancel Processing")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(Color.red.opacity(0.8))
                    .clipShape(Capsule())
            }
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Completed View
    
    private var completedView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.green)
                
                Text("Model Saved!")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Your 3D model has been saved to the library")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                
                // Show model info
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "photo.stack.fill")
                            .foregroundColor(.blue)
                        Text("\(captureSessionManager.capturedImageCount) images processed")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.green)
                        Text("Scanned in \(captureSessionManager.formattedCaptureDuration)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            
            Spacer()
            
            Button {
                dismiss()
            } label: {
                Text("Back to Library")
                    .font(.headline)
                    .foregroundColor(.black)
                    .padding(.horizontal, 48)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Failed View
    
    private var failedView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.red)
                
                Text("Scan Failed")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                if let error = captureSessionManager.errorMessage {
                    Text(error)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            
            Spacer()
            
            VStack(spacing: 12) {
                Button {
                    captureSessionManager.reset()
                    showingNameInput = true
                } label: {
                    Text("Try Again")
                        .font(.headline)
                        .foregroundColor(.black)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
                
                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Preview View
    
    private var previewView: some View {
        VStack(spacing: 24) {
            if let modelURL = captureSessionManager.previewModelURL {
                ARQuickLookView(modelFileURL: modelURL)
            } else {
                Text("Model file not available")
                    .foregroundColor(.white)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getNextPass() -> CapturePass? {
        switch captureSessionManager.currentPass {
        case .sides:
            return .top
        case .top:
            return .bottom
        case .bottom:
            return nil
        }
    }
    
    private func getButtonText() -> String {
        guard let sessionState = captureSessionManager.sessionState else {
            return "Start Detection"
        }
        
        switch sessionState {
        case .ready:
            return "Start Detection"
        case .detecting:
            return "Start Capturing"
        case .capturing:
            return "Capturing..."
        default:
            return "Processing..."
        }
    }
    
    private func getStepDisplayName() -> String {
        guard let sessionState = captureSessionManager.sessionState else {
            return "Object Detection"
        }
        
        switch sessionState {
        case .ready:
            return "Object Detection"
        case .detecting:
            return "Object Detected"
        case .capturing:
            return "Capturing Object"
        case .finishing:
            return "Finishing Capture"
        default:
            return "Processing"
        }
    }
    
    private func getStepInstruction() -> String {
        guard let sessionState = captureSessionManager.sessionState else {
            return "Point camera at object and tap 'Start Detection'"
        }
        
        switch sessionState {
        case .ready:
            return "Point camera at object and tap 'Start Detection'"
        case .detecting:
            return "Object detected! Tap 'Start Capturing' to begin scanning"
        case .capturing:
            return captureSessionManager.currentPass.instruction
        case .finishing:
            return "Completing capture..."
        default:
            return "Processing your 3D model..."
        }
    }
    
    private func startCapture() {
        // Check camera permission
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            captureSessionManager.startCaptureSession(
                modelName: modelName,
                storageService: fileStorageService
            )
        case .denied, .restricted:
            showingCameraPermissionDenied = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        captureSessionManager.startCaptureSession(
                            modelName: modelName,
                            storageService: fileStorageService
                        )
                    } else {
                        showingCameraPermissionDenied = true
                    }
                }
            }
        @unknown default:
            showingCameraPermissionDenied = true
        }
    }
}



// MARK: - Supporting Views

/// Simple loading view with a progress indicator and text
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
            
            Text("Loading...")
                .font(.headline)
                .foregroundColor(.white)
        }
        .padding(32)
    }
}

struct ARQuickLookView: UIViewControllerRepresentable {
    let modelFileURL: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }

    class Coordinator: NSObject, QLPreviewControllerDelegate, QLPreviewControllerDataSource {
        let parent: ARQuickLookView

        init(parent: ARQuickLookView) {
            self.parent = parent
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            let item = ARQuickLookPreviewItem(fileAt: parent.modelFileURL)
            item.allowsContentScaling = true
            return item
        }
    }
}



// MARK: - Preview

#if DEBUG
struct ObjectCaptureWorkflowView_Previews: PreviewProvider {
    static var previews: some View {
        ObjectCaptureWorkflowView()
            .environmentObject(FileStorageService.shared)
            .environmentObject(CaptureSessionManager())
    }
}
#endif 