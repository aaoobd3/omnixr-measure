//
//  FileStorageService.swift
//  omnixr-measure
//
//  Created by phones luxury on 02/07/2025.
//

import Foundation
import SwiftUI
import Combine

/// Service for managing 3D model files and metadata storage
/// Handles file operations in the app's Documents directory following MVVM pattern
@MainActor
class FileStorageService: ObservableObject {
    
    static let shared = FileStorageService()
    
    // MARK: - Published Properties
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Directory Structure
    
    private let documentsDirectory: URL
    private let modelsDirectory: URL
    private let metadataDirectory: URL
    private let thumbnailsDirectory: URL
    private let tempDirectory: URL
    
    // MARK: - File Management
    
    private let fileManager = FileManager.default
    private let metadataFileName = "models_metadata.json"
    
    private init() {
        // Setup directory structure
        self.documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.modelsDirectory = documentsDirectory.appendingPathComponent("Models")
        self.metadataDirectory = documentsDirectory.appendingPathComponent("Metadata") 
        self.thumbnailsDirectory = documentsDirectory.appendingPathComponent("Thumbnails")
        self.tempDirectory = documentsDirectory.appendingPathComponent("Temp")
        
        print("📁 Storage initialized:")
        print("  Documents: \(documentsDirectory.path)")
        print("  Models: \(modelsDirectory.path)")
        print("  Metadata: \(metadataDirectory.path)")
        print("  Thumbnails: \(thumbnailsDirectory.path)")
    }
    
    // MARK: - Initialization
    
    /// Initialize storage directories on app launch
    func initializeStorageDirectories() {
        createDirectoryIfNeeded(modelsDirectory)
        createDirectoryIfNeeded(metadataDirectory)
        createDirectoryIfNeeded(thumbnailsDirectory)
        createDirectoryIfNeeded(tempDirectory)
        
        // Clean up temp directory
        cleanupTempDirectory()
        
        print("✅ Storage directories initialized")
    }
    
    private func createDirectoryIfNeeded(_ directory: URL) {
        if !fileManager.fileExists(atPath: directory.path) {
            do {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
                print("📂 Created directory: \(directory.lastPathComponent)")
            } catch {
                print("❌ Failed to create directory \(directory.lastPathComponent): \(error)")
            }
        }
    }
    
    // MARK: - Model Loading
    
    /// Load all scanned models from storage
    func loadAllModels() async -> [ScannedModel] {
        isLoading = true
        defer { isLoading = false }
        
        // Primary approach: Load from actual files first
        let fileModels = await loadModelsFromFiles()
        
        // Secondary: Load metadata for additional details
        let metadataModels = await loadModelsFromMetadata()
        
        // Merge: Use file models as base, enhance with metadata where available
        var finalModels: [ScannedModel] = []
        
        for fileModel in fileModels {
            // Try to find matching metadata model
            if let metadataModel = metadataModels.first(where: { $0.name == fileModel.name }) {
                // Use metadata model (it has more complete information)
                finalModels.append(metadataModel)
            } else {
                // Use file model as fallback
                finalModels.append(fileModel)
            }
        }
        
        let sortedModels = finalModels.sorted { $0.createdDate > $1.createdDate }
        print("📦 Final loaded models: \(sortedModels.count)")
        
        return sortedModels
    }
    
    /// Load models from metadata file
    private func loadModelsFromMetadata() async -> [ScannedModel] {
        do {
            let metadataURL = metadataDirectory.appendingPathComponent(metadataFileName)
            
            guard fileManager.fileExists(atPath: metadataURL.path) else {
                print("📄 No metadata file found")
                return []
            }
            
            let data = try Data(contentsOf: metadataURL)
            let models = try JSONDecoder().decode([ScannedModel].self, from: data)
            
            print("📚 Metadata library contents:")
            for model in models {
                let currentURLs = model.getCurrentFileURLs()
                let exists = fileManager.fileExists(atPath: currentURLs.usdz.path)
                print("  - \(model.name) (\(exists ? "EXISTS" : "MISSING")) - \(currentURLs.usdz.path)")
            }
            
            // Return all models (including missing files for user to manage)
            return models
            
        } catch {
            print("❌ Failed to load metadata: \(error)")
            return []
        }
    }
    
    /// Load models from actual files in directory
    private func loadModelsFromFiles() async -> [ScannedModel] {
        do {
            print("📁 Scanning actual files in: \(modelsDirectory.path)")
            
            let fileURLs = try fileManager.contentsOfDirectory(at: modelsDirectory, includingPropertiesForKeys: [.creationDateKey, .fileSizeKey])
            let usdzFiles = fileURLs.filter { $0.pathExtension.lowercased() == "usdz" }
            
            print("📄 Found \(usdzFiles.count) .usdz files:")
            for url in usdzFiles {
                print("  - \(url.lastPathComponent)")
            }
            
            var models: [ScannedModel] = []
            
            for usdzURL in usdzFiles {
                let fileName = usdzURL.deletingPathExtension().lastPathComponent
                let modelName = extractModelName(from: fileName)
                
                // Get file attributes
                let attributes = try fileManager.attributesOfItem(atPath: usdzURL.path)
                let creationDate = attributes[.creationDate] as? Date ?? Date()
                let fileSize = attributes[.size] as? Int64 ?? 0
                
                // Generate corresponding thumbnail and metadata URLs
                let thumbnailURL = thumbnailsDirectory.appendingPathComponent("\(fileName).jpg")
                let metadataURL = metadataDirectory.appendingPathComponent("\(fileName).json")
                
                let model = ScannedModel(
                    name: modelName,
                    createdDate: creationDate,
                    usdzFileURL: usdzURL,
                    thumbnailImageURL: thumbnailURL,
                    metadataFileURL: metadataURL,
                    scanDuration: 0, // Unknown from file
                    numberOfImages: 0, // Unknown from file
                    fileSize: fileSize,
                    dimensions: ModelDimensions(width: 0.1, height: 0.1, depth: 0.1),
                    qualityScore: 0.5,
                    detailLevel: .medium,
                    hasLiDARData: false
                )
                
                models.append(model)
                print("📦 Created model from file: \(modelName)")
            }
            
            return models
            
        } catch {
            print("❌ Failed to scan files: \(error)")
            return []
        }
    }
    
    /// Extract model name from filename (remove UUID suffix)
    private func extractModelName(from fileName: String) -> String {
        // Remove UUID suffix like "Sgt_3A9B5DB5" -> "Sgt"
        let components = fileName.components(separatedBy: "_")
        if components.count > 1 {
            return components.dropLast().joined(separator: "_")
        }
        return fileName
    }
    
    // MARK: - Model Saving
    
    /// Save a new scanned model to storage
    func saveModel(_ model: ScannedModel) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Save model metadata
            var existingModels = await loadAllModels()
            
            // Remove any existing model with the same ID
            existingModels.removeAll { $0.id == model.id }
            
            // Add new model
            existingModels.append(model)
            
            // Save updated metadata
            let metadataURL = metadataDirectory.appendingPathComponent(metadataFileName)
            let data = try JSONEncoder().encode(existingModels)
            try data.write(to: metadataURL)
            
            print("💾 Saved model: \(model.name)")
            return true
            
        } catch {
            print("❌ Failed to save model: \(error)")
            errorMessage = "Failed to save model: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Model Deletion
    
    /// Delete models from storage
    func deleteModels(_ models: [ScannedModel]) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Delete physical files
            for model in models {
                let currentURLs = model.getCurrentFileURLs()
                try? fileManager.removeItem(at: currentURLs.usdz)
                try? fileManager.removeItem(at: currentURLs.thumbnail)
                try? fileManager.removeItem(at: currentURLs.metadata)
                print("🗑️ Deleted files for: \(model.name)")
            }
            
            // Update metadata index
            var existingModels = await loadAllModels()
            let modelIDs = Set(models.map { $0.id })
            existingModels.removeAll { modelIDs.contains($0.id) }
            
            // Save updated metadata
            let metadataURL = metadataDirectory.appendingPathComponent(metadataFileName)
            let data = try JSONEncoder().encode(existingModels)
            try data.write(to: metadataURL)
            
            print("✅ Deleted \(models.count) models from storage")
            return true
            
        } catch {
            print("❌ Failed to delete models: \(error)")
            errorMessage = "Failed to delete models: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - File URLs Generation
    
    /// Generate file URLs for a new model
    func generateFileURLs(for modelName: String, modelID: UUID = UUID()) -> (usdz: URL, thumbnail: URL, metadata: URL) {
        let sanitizedName = sanitizeFileName(modelName)
        let uniqueName = "\(sanitizedName)_\(modelID.uuidString.prefix(8))"
        
        let usdzURL = modelsDirectory.appendingPathComponent("\(uniqueName).usdz")
        let thumbnailURL = thumbnailsDirectory.appendingPathComponent("\(uniqueName).jpg")
        let metadataURL = metadataDirectory.appendingPathComponent("\(uniqueName).json")
        
        return (usdzURL, thumbnailURL, metadataURL)
    }
    
    private func sanitizeFileName(_ name: String) -> String {
        let allowedCharacters = CharacterSet.alphanumerics.union(.init(charactersIn: "-_"))
        return String(name.unicodeScalars.compactMap { allowedCharacters.contains($0) ? Character($0) : nil })
    }
    
    // MARK: - Storage Statistics
    
    /// Get storage information
    func getStorageInfo() async -> StorageInfo {
        let models = await loadAllModels()
        
        let totalSize = models.reduce(0) { $0 + $1.fileSize }
        
        return StorageInfo(
            totalSize: totalSize,
            numberOfModels: models.count
        )
    }
    
    // MARK: - Export and Share
    
    /// Export model to Files app or share sheet
    func exportModel(_ model: ScannedModel, to destinationURL: URL? = nil) async -> Bool {
        do {
            if let destinationURL = destinationURL {
                let currentURLs = model.getCurrentFileURLs()
                try fileManager.copyItem(at: currentURLs.usdz, to: destinationURL)
                print("📤 Exported model to: \(destinationURL.path)")
            }
            return true
        } catch {
            print("❌ Failed to export model: \(error)")
            errorMessage = "Failed to export model: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Temporary File Management
    
    /// Get temporary directory for capture workflow
    func getTempDirectory() -> URL {
        return tempDirectory
    }
    
    /// Clean up temporary files
    func cleanupTempDirectory() {
        do {
            let contents = try fileManager.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
            for url in contents {
                try fileManager.removeItem(at: url)
            }
            print("🧹 Cleaned up temp directory")
        } catch {
            print("⚠️ Failed to clean temp directory: \(error)")
        }
    }
    
    /// Move file from temp to permanent storage
    func moveFromTemp(tempURL: URL, to permanentURL: URL) async -> Bool {
        do {
            // Ensure destination directory exists
            let destinationDirectory = permanentURL.deletingLastPathComponent()
            createDirectoryIfNeeded(destinationDirectory)
            
            // Move file
            try fileManager.moveItem(at: tempURL, to: permanentURL)
            print("📁 Moved file: \(tempURL.lastPathComponent) → \(permanentURL.lastPathComponent)")
            return true
        } catch {
            print("❌ Failed to move file: \(error)")
            errorMessage = "Failed to move file: \(error.localizedDescription)"
            return false
        }
    }
    
    /// Clean up library entries with missing files
    func cleanupMissingFiles() async -> Bool {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let allModels = await loadModelsFromMetadata()
            let validModels = allModels.filter { $0.filesExist() }
            let removedCount = allModels.count - validModels.count
            
            if removedCount > 0 {
                // Save updated metadata with only valid models
                let metadataURL = metadataDirectory.appendingPathComponent(metadataFileName)
                let data = try JSONEncoder().encode(validModels)
                try data.write(to: metadataURL)
                
                print("🧹 Cleaned up \(removedCount) missing file entries from library")
                return true
            } else {
                print("✅ No missing file entries to clean")
                return true
            }
            
        } catch {
            print("❌ Failed to cleanup library: \(error)")
            errorMessage = "Failed to cleanup library: \(error.localizedDescription)"
            return false
        }
    }
}

// MARK: - File Size Calculation

extension FileStorageService {
    
    /// Calculate file size at URL
    func fileSize(at url: URL) -> Int64 {
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
    
    /// Calculate directory size recursively
    func directorySize(at url: URL) -> Int64 {
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                totalSize += Int64(resourceValues.fileSize ?? 0)
            } catch {
                continue
            }
        }
        
        return totalSize
    }
} 