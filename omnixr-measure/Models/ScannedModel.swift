//
//  ScannedModel.swift
//  omnixr-measure
//
//  Created by phones luxury on 02/07/2025.
//

import Foundation
import SwiftUI

/// Represents a scanned 3D model with metadata and file references
/// Core data model for the MVVM architecture
struct ScannedModel: Identifiable, Codable, Hashable {
    
    let id: UUID
    let name: String
    let createdDate: Date
    let lastModifiedDate: Date
    
    // File references
    let usdzFileURL: URL
    let thumbnailImageURL: URL
    let metadataFileURL: URL
    
    // Model metadata
    let scanDuration: TimeInterval
    let numberOfImages: Int
    let fileSize: Int64 // in bytes
    let dimensions: ModelDimensions
    let surfaceArea: Double? // in square meters
    
    // Scan quality metrics
    let qualityScore: Double // 0.0 to 1.0
    let detailLevel: ModelDetailLevel
    let hasLiDARData: Bool
    
    init(
        id: UUID = UUID(),
        name: String,
        createdDate: Date = Date(),
        usdzFileURL: URL,
        thumbnailImageURL: URL,
        metadataFileURL: URL,
        scanDuration: TimeInterval,
        numberOfImages: Int,
        fileSize: Int64,
        dimensions: ModelDimensions,
        surfaceArea: Double? = nil,
        qualityScore: Double,
        detailLevel: ModelDetailLevel,
        hasLiDARData: Bool = false
    ) {
        self.id = id
        self.name = name
        self.createdDate = createdDate
        self.lastModifiedDate = createdDate
        self.usdzFileURL = usdzFileURL
        self.thumbnailImageURL = thumbnailImageURL
        self.metadataFileURL = metadataFileURL
        self.scanDuration = scanDuration
        self.numberOfImages = numberOfImages
        self.fileSize = fileSize
        self.dimensions = dimensions
        self.surfaceArea = surfaceArea
        self.qualityScore = qualityScore
        self.detailLevel = detailLevel
        self.hasLiDARData = hasLiDARData
    }
}

// MARK: - Supporting Types

/// Model detail level for Object Capture output
enum ModelDetailLevel: String, Codable, CaseIterable {
    case reduced = "reduced"
    case medium = "medium"
    case full = "full"
    case raw = "raw"
    
    var displayName: String {
        switch self {
        case .reduced: return "Reduced"
        case .medium: return "Medium"
        case .full: return "Full"
        case .raw: return "Raw"
        }
    }
    
    var description: String {
        switch self {
        case .reduced: return "Optimized for mobile/web (smallest file size)"
        case .medium: return "Balanced quality and file size"
        case .full: return "High quality for professional use"
        case .raw: return "Maximum detail for post-production"
        }
    }
}

/// 3D model dimensions in meters
struct ModelDimensions: Codable, Hashable {
    let width: Float   // X-axis
    let height: Float  // Y-axis
    let depth: Float   // Z-axis
    
    /// Bounding box volume in cubic meters
    var volume: Float {
        return width * height * depth
    }
    
    /// Formatted dimension string
    var formattedString: String {
        return String(format: "%.2f × %.2f × %.2f m", width, height, depth)
    }
    
    /// Compact formatted dimension string
    var compactString: String {
        return String(format: "%.1f×%.1f×%.1f m", width, height, depth)
    }
}

// MARK: - Extensions

extension ScannedModel {
    
    /// Formatted file size string
    var formattedFileSize: String {
        return ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
    /// Formatted surface area string
    var formattedSurfaceArea: String {
        guard let surfaceArea = surfaceArea else { return "Unknown" }
        
        if surfaceArea < 0.01 {
            // Show in square centimeters for small objects
            let cm2 = surfaceArea * 10000 // m² to cm²
            return String(format: "%.1f cm²", cm2)
        } else {
            // Show in square meters for larger objects
            return String(format: "%.3f m²", surfaceArea)
        }
    }
    
    /// Formatted scan duration string
    var formattedScanDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: scanDuration) ?? "\(Int(scanDuration))s"
    }
    
    /// Quality level description
    var qualityDescription: String {
        switch qualityScore {
        case 0.8...1.0: return "Excellent"
        case 0.6..<0.8: return "Good"
        case 0.4..<0.6: return "Fair"
        case 0.2..<0.4: return "Poor"
        default: return "Very Poor"
        }
    }
    
    /// Quality color for UI
    var qualityColor: Color {
        switch qualityScore {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .blue
        case 0.4..<0.6: return .yellow
        case 0.2..<0.4: return .orange
        default: return .red
        }
    }
    
    /// Check if model files exist on disk
    func filesExist() -> Bool {
        let fileManager = FileManager.default
        
        // First check if the stored paths still work
        if fileManager.fileExists(atPath: usdzFileURL.path) {
            return true
        }
        
        // Fallback: reconstruct current paths
        let currentURLs = getCurrentFileURLs()
        let exists = fileManager.fileExists(atPath: currentURLs.usdz.path)
        
        if exists {
            print("📍 Found model at reconstructed path: \(currentURLs.usdz.path)")
        } else {
            print("❌ Model not found at stored path: \(usdzFileURL.path)")
            print("❌ Model not found at current path: \(currentURLs.usdz.path)")
        }
        
        return exists
    }
    
    /// Get current file URLs (reconstructed from current documents directory)
    func getCurrentFileURLs() -> (usdz: URL, thumbnail: URL, metadata: URL) {
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return (usdzFileURL, thumbnailImageURL, metadataFileURL)
        }
        
        let currentUsdzURL = documentsDirectory.appendingPathComponent("Models/\(usdzFileURL.lastPathComponent)")
        let currentThumbnailURL = documentsDirectory.appendingPathComponent("Thumbnails/\(thumbnailImageURL.lastPathComponent)")
        let currentMetadataURL = documentsDirectory.appendingPathComponent("Metadata/\(metadataFileURL.lastPathComponent)")
        
        return (currentUsdzURL, currentThumbnailURL, currentMetadataURL)
    }
    
    /// Generate share items for export
    func shareItems() -> [Any] {
        var items: [Any] = []
        
        // Add USDZ file (use current path)
        items.append(getCurrentFileURLs().usdz)
        
        // Add metadata as text
        let metadata = """
        3D Model: \(name)
        Created: \(createdDate.formatted())
        Dimensions: \(dimensions.formattedString)
        Surface Area: \(formattedSurfaceArea)
        File Size: \(formattedFileSize)
        Quality: \(qualityDescription)
        Scan Duration: \(formattedScanDuration)
        Images Used: \(numberOfImages)
        Detail Level: \(detailLevel.displayName)
        """
        items.append(metadata)
        
        return items
    }
}

// StorageInfo is defined in StorageInfo.swift 