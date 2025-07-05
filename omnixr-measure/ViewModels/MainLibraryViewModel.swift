//
//  MainLibraryViewModel.swift
//  omnixr-measure
//
//  Created by phones luxury on 02/07/2025.
//

import Foundation
import SwiftUI
import Combine

/// View model for the main library view following MVVM architecture
/// Manages the state of scanned models and coordinates with storage service
@MainActor
class MainLibraryViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var models: [ScannedModel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var storageInfo: StorageInfo?
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        print("📱 MainLibraryViewModel initialized")
    }
    
    // MARK: - Model Loading
    
    /// Load models from storage service
    func loadModels(from storageService: FileStorageService) async {
        isLoading = true
        errorMessage = nil
        
        let loadedModels = await storageService.loadAllModels()
        models = loadedModels.sorted { $0.createdDate > $1.createdDate }
        
        // Update storage info
        storageInfo = await storageService.getStorageInfo()
        
        print("📦 Loaded \(models.count) models in view model")
        
        isLoading = false
    }
    
    // MARK: - Model Operations
    
    /// Delete models using storage service
    func deleteModels(_ modelsToDelete: [ScannedModel], from storageService: FileStorageService) async {
        isLoading = true
        
        let success = await storageService.deleteModels(modelsToDelete)
        
        if success {
            // Remove from local array
            let deletedIDs = Set(modelsToDelete.map { $0.id })
            models.removeAll { deletedIDs.contains($0.id) }
            
            // Update storage info
            storageInfo = await storageService.getStorageInfo()
            
            print("✅ Successfully deleted \(modelsToDelete.count) models")
        } else {
            errorMessage = "Failed to delete models"
            print("❌ Failed to delete models")
        }
        
        isLoading = false
    }
    
    /// Add a new model to the collection
    func addModel(_ model: ScannedModel) {
        // Insert at beginning to show newest first
        models.insert(model, at: 0)
        print("➕ Added new model: \(model.name)")
    }
    
    // MARK: - Search and Filtering
    
    /// Filter models by name
    func filteredModels(searchText: String) -> [ScannedModel] {
        guard !searchText.isEmpty else { return models }
        
        return models.filter { model in
            model.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    /// Group models by creation date
    func groupedModels() -> [(String, [ScannedModel])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: models) { model in
            calendar.dateInterval(of: .day, for: model.createdDate)?.start ?? model.createdDate
        }
        
        return grouped.map { (date, models) in
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return (formatter.string(from: date), models.sorted { $0.createdDate > $1.createdDate })
        }.sorted { $0.0 > $1.0 }
    }
    
    // MARK: - Statistics
    
    /// Get model statistics
    var modelStatistics: ModelStatistics {
        let totalFileSize = models.reduce(0) { $0 + $1.fileSize }
        let averageQuality = models.isEmpty ? 0 : models.reduce(0) { $0 + $1.qualityScore } / Double(models.count)
        let totalSurfaceArea = models.compactMap { $0.surfaceArea }.reduce(0, +)
        
        return ModelStatistics(
            totalModels: models.count,
            totalFileSize: totalFileSize,
            averageQuality: averageQuality,
            totalSurfaceArea: totalSurfaceArea
        )
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
}

// MARK: - Supporting Types

/// Statistics about the model collection
struct ModelStatistics {
    let totalModels: Int
    let totalFileSize: Int64
    let averageQuality: Double
    let totalSurfaceArea: Double
    
    var formattedTotalFileSize: String {
        ByteCountFormatter.string(fromByteCount: totalFileSize, countStyle: .file)
    }
    
    var formattedAverageQuality: String {
        String(format: "%.1f%%", averageQuality * 100)
    }
    
    var formattedTotalSurfaceArea: String {
        if totalSurfaceArea < 0.01 {
            let cm2 = totalSurfaceArea * 10000
            return String(format: "%.1f cm²", cm2)
        } else {
            return String(format: "%.3f m²", totalSurfaceArea)
        }
    }
} 