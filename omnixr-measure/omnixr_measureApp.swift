//
//  omnixr_measureApp.swift
//  omnixr-measure
//
//  Created by phones luxury on 02/07/2025.
//

import SwiftUI
import AVFoundation
import ARKit
import RealityKit
// TODO: Add ARKit and RealityKit imports when frameworks are linked in Xcode

/// Main app entry point for OmniXR Measure
/// A production-quality 3D model scanning and measurement app using Apple's Object Capture API
@main
struct omnixr_measureApp: App {
    
    @StateObject private var fileStorageService = FileStorageService.shared
    @StateObject private var captureSessionManager = CaptureSessionManager()
    
    var body: some SwiftUI.Scene {
        WindowGroup {
            ContentView()
                .environmentObject(fileStorageService)
                .environmentObject(captureSessionManager)
                .onAppear {
                    setupApp()
                }
        }
    }
    
    /// Initial app setup and configuration
    private func setupApp() {
        // Request camera and photo library permissions on app launch
        requestPermissions()
        
        // Initialize storage directories
        fileStorageService.initializeStorageDirectories()
        
        // Setup ARKit and RealityKit configurations
        setupARKit()
    }
    
    /// Request required permissions for camera and photo library access
    private func requestPermissions() {
        // Camera permission for Object Capture
        AVCaptureDevice.requestAccess(for: .video) { granted in
            if granted {
                print("✅ Camera access granted")
            } else {
                print("❌ Camera access denied - Object Capture will not function")
            }
        }
        
        // Photo library permission for saving captured images
        // Note: This would typically use PHPhotoLibrary.requestAuthorization
        // but since we're using app Documents directory, we don't need this
        print("📁 Using app Documents directory for storage")
    }
    
    /// Setup ARKit configuration for the app
    private func setupARKit() {
        // Check for ARKit availability
        #if canImport(ARKit)
        guard ARWorldTrackingConfiguration.isSupported else {
            print("❌ ARKit not supported on this device")
            return
        }
        
        print("✅ ARKit available and supported")
        #endif
        
        // Check for Object Capture capability with error handling
        if #available(iOS 17.0, *) {
            let isSupported = ObjectCaptureSession.isSupported
            if isSupported {
                print("✅ Object Capture API available")
            } else {
                print("⚠️ Object Capture not supported on this device")
            }
        } else {
            print("⚠️ Object Capture requires iOS 17+")
        }
        
        print("🔍 ARKit setup completed")
    }
}
