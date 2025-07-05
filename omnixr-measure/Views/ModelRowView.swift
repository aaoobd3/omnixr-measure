//
//  ModelRowView.swift
//  omnixr-measure
//
//  Created by phones luxury on 02/07/2025.
//

import SwiftUI

/// Individual row view for displaying a scanned 3D model in the library list
struct ModelRowView: View {
    
    let model: ScannedModel
    let isEditing: Bool
    let isSelected: Bool
    let onTap: (ScannedModel) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Selection indicator for edit mode
            if isEditing {
                Button {
                    onTap(model)
                } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .gray)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            
            // Model information
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(model.name)
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(model.formattedFileSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text(model.createdDate, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // File status indicator
                    HStack(spacing: 4) {
                        if model.filesExist() {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text("Ready")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                            Text("Missing Files")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap(model)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ModelRowView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleModel = ScannedModel(
            name: "Sample Object",
            usdzFileURL: URL(fileURLWithPath: "/sample.usdz"),
            thumbnailImageURL: URL(fileURLWithPath: "/sample.jpg"),
            metadataFileURL: URL(fileURLWithPath: "/sample.json"),
            scanDuration: 120,
            numberOfImages: 45,
            fileSize: 2_500_000,
            dimensions: ModelDimensions(width: 0.15, height: 0.08, depth: 0.12),
            surfaceArea: 0.045,
            qualityScore: 0.85,
            detailLevel: .medium,
            hasLiDARData: true
        )
        
        VStack {
            ModelRowView(
                model: sampleModel,
                isEditing: false,
                isSelected: false
            ) { _ in }
            
            ModelRowView(
                model: sampleModel,
                isEditing: true,
                isSelected: true
            ) { _ in }
        }
        .padding()
    }
}
#endif 