//
//  StorageInfo.swift
//  omnixr-measure
//
//  Created by phones luxury on 02/07/2025.
//

import Foundation

/// Storage information for the 3D model library
struct StorageInfo: Codable {
    let totalSize: Int64
    let numberOfModels: Int
    
    /// Formatted size string
    var formattedSize: String {
        return ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
    
    /// Average file size per model
    var averageFileSize: Int64 {
        guard numberOfModels > 0 else { return 0 }
        return totalSize / Int64(numberOfModels)
    }
    
    /// Formatted average file size string
    var formattedAverageSize: String {
        return ByteCountFormatter.string(fromByteCount: averageFileSize, countStyle: .file)
    }
} 