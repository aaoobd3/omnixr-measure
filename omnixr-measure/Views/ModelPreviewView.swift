//
//  ModelPreviewView.swift
//  omnixr-measure
//
//  Created by phones luxury on 02/07/2025.
//

import SwiftUI
import ModelIO
import SceneKit
import UIKit
import RealityKit
import simd
import ARKit

/// Enhanced model preview view with surface area calculation
struct ModelPreviewView: View {
    
    let model: ScannedModel
    @EnvironmentObject private var fileStorageService: FileStorageService
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingQuickLook = false
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var calculatedSurfaceArea: Double?
    @State private var isCalculating = false
    @State private var calculationError: String?
    @State private var faceCount: Int?
    @State private var vertexCount: Int?
    @State private var boundingBoxSurfaceArea: Double?
    @State private var complexityRatio: Double?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Content sections
                VStack(spacing: 24) {
                    // Surface area calculation
                    surfaceAreaSection
                    
                    // Action buttons
                    actionButtonsSection
                }
                .padding(20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Share") {
                    showingShareSheet = true
                }
                .disabled(!model.filesExist())
            }
        }
        .fullScreenCover(isPresented: $showingQuickLook) {
            ARQuickLookViewController(usdzURL: model.getCurrentFileURLs().usdz, isPresented: $showingQuickLook)
        }
        .sheet(isPresented: $showingShareSheet) {
            if model.filesExist() {
                ActivityView(activityItems: [model.getCurrentFileURLs().usdz])
            }
        }
    }
    
    // MARK: - Surface Area Section
    
    private var surfaceAreaSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Mesh Analysis", icon: "triangle.fill")
            
            VStack(spacing: 16) {
                // Surface area card
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "grid.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text("Surface Area")
                                .font(.headline)
                            
                            if let surfaceArea = calculatedSurfaceArea {
                                Text(formatSurfaceArea(surfaceArea))
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                            } else if let modelSurfaceArea = model.surfaceArea {
                                Text(model.formattedSurfaceArea)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                            } else {
                                Text("Unknown")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if isCalculating {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    
                    // Mesh details
                    if let faceCount = faceCount, let vertexCount = vertexCount {
                        VStack(spacing: 8) {
                            HStack {
                                Text("Faces:")
                                Spacer()
                                Text("\(faceCount)")
                                    .fontWeight(.semibold)
                            }
                            
                            HStack {
                                Text("Vertices:")
                                Spacer()
                                Text("\(vertexCount)")
                                    .fontWeight(.semibold)
                            }
                            
                            // Bounding box comparison
                            if let boundingBoxArea = boundingBoxSurfaceArea,
                               let complexityRatio = complexityRatio {
                                Divider()
                                    .padding(.vertical, 4)
                                
                                HStack {
                                    Text("Bounding Box Area:")
                                    Spacer()
                                    Text(formatSurfaceArea(boundingBoxArea))
                                        .fontWeight(.semibold)
                                }
                                
                                HStack {
                                    Text("Complexity Ratio:")
                                    Spacer()
                                    Text(String(format: "%.2f×", complexityRatio))
                                        .fontWeight(.semibold)
                                        .foregroundColor(complexityRatio > 2.0 ? .green : complexityRatio > 1.5 ? .orange : .blue)
                                }
                                
                                if complexityRatio > 2.0 {
                                    Text("✨ Highly detailed geometry")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                } else if complexityRatio > 1.5 {
                                    Text("🔍 Moderate complexity")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                } else {
                                    Text("📐 Simple geometry")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    }
                    
                    // Calculate button
                    Button(action: calculateSurfaceArea) {
                        HStack {
                            Image(systemName: "function")
                            Text(calculatedSurfaceArea == nil ? "Calculate Surface Area" : "Recalculate")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    .disabled(isCalculating || !model.filesExist())
                    
                    // Error message
                    if let error = calculationError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(16)
            }
        }
    }
    
    // MARK: - Action Buttons Section
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // Open 3D Model button
            Button(action: {
                if model.filesExist() {
                    showingQuickLook = true
                }
            }) {
                HStack {
                    Image(systemName: "arkit")
                    Text("View in AR")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(
                        colors: model.filesExist() ? [.blue, .purple] : [.gray, .gray],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
            }
            .disabled(!model.filesExist())
            
            // Download to Files button
            Button(action: {
                if model.filesExist() {
                    exportToFiles()
                }
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                    Text("Download to Files")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(
                        colors: model.filesExist() ? [.green, .teal] : [.gray, .gray],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
            }
            .disabled(!model.filesExist())
        }
    }
    
    // MARK: - Surface Area Calculation
    
    private func calculateSurfaceArea() {
        guard model.filesExist() else { return }
        
        isCalculating = true
        calculationError = nil
        
        Task {
            do {
                let result = try await calculateMeshSurfaceArea()
                await MainActor.run {
                    self.calculatedSurfaceArea = result.surfaceArea
                    self.faceCount = result.faceCount
                    self.vertexCount = result.vertexCount
                    self.boundingBoxSurfaceArea = result.boundingBoxArea
                    self.complexityRatio = result.complexityRatio
                    self.isCalculating = false
                }
            } catch {
                await MainActor.run {
                    self.calculationError = "Failed to calculate: \(error.localizedDescription)"
                    self.isCalculating = false
                }
            }
        }
    }
    
    private func calculateMeshSurfaceArea() async throws -> (surfaceArea: Double, faceCount: Int, vertexCount: Int, boundingBoxArea: Double, complexityRatio: Double) {
        let modelURL = model.getCurrentFileURLs().usdz
        
        do {
            let modelEntity = try await ModelEntity.loadModel(contentsOf: modelURL)
            
            guard let mesh = modelEntity.model?.mesh else {
                throw NSError(domain: "SurfaceAreaError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mesh resource not found."])
            }
            
            var totalSurfaceArea: Double = 0
            var totalFaceCount = 0
            var totalVertexCount = 0

            for model in mesh.contents.models {
                for part in model.parts {
                    let positions = part.positions.elements
                    totalVertexCount += positions.count

                    if let triangleIndices = part.triangleIndices?.elements {
                        totalFaceCount += triangleIndices.count / 3
                        for i in stride(from: 0, to: triangleIndices.count, by: 3) {
                            let i0 = Int(triangleIndices[i])
                            let i1 = Int(triangleIndices[i+1])
                            let i2 = Int(triangleIndices[i+2])

                            guard i0 < positions.count, i1 < positions.count, i2 < positions.count else { continue }
                            
                            let v0 = positions[i0]
                            let v1 = positions[i1]
                            let v2 = positions[i2]

                            let side1 = v1 - v0
                            let side2 = v2 - v0
                            let crossProduct = cross(side1, side2)
                            let area = 0.5 * simd_length(crossProduct)
                            totalSurfaceArea += Double(area)
                        }
                    }
                }
            }
            
            let bounds = modelEntity.visualBounds(relativeTo: nil)
            let extents = bounds.extents
            let boundingBoxArea = Double(2 * (extents.x * extents.y + extents.y * extents.z + extents.x * extents.z))
                        
            let complexityRatio = (boundingBoxArea > 0) ? totalSurfaceArea / boundingBoxArea : 0
            
            print("📐 RealityKit mesh analysis completed:")
            print("   - Surface Area: \(totalSurfaceArea) m²")
            print("   - Face Count: \(totalFaceCount)")
            print("   - Vertex Count: \(totalVertexCount)")
            print("   - Bounding Box Area: \(boundingBoxArea) m²")
            print("   - Complexity Ratio: \(complexityRatio)")
            
            return (totalSurfaceArea, totalFaceCount, totalVertexCount, boundingBoxArea, complexityRatio)
            
        } catch {
            print("❌ Failed to analyze mesh with RealityKit: \(error)")
            throw error
        }
    }

    private func formatSurfaceArea(_ area: Double) -> String {
        return String(format: "%.4f m²", area)
    }
    
    // MARK: - Export to Files
    
    private func exportToFiles() {
        let usdzURL = model.getCurrentFileURLs().usdz
        shareItems = [usdzURL]
        showingShareSheet = true
    }
}

// MARK: - Supporting Views

struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
        }
    }
}

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

struct DetailCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        
        // Set subject for the share sheet
        if let firstURL = activityItems.first as? URL {
            controller.setValue("3D Model: \(firstURL.lastPathComponent)", forKey: "subject")
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

// MARK: - Preview

struct ModelPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        let model = ScannedModel(
            name: "Vintage Toy Car",
            usdzFileURL: URL(fileURLWithPath: "/Users/phonesluxury/Desktop/omnixr-measure/Models/toy_car.usdz"),
            thumbnailImageURL: URL(fileURLWithPath: ""), // Dummy URL
            metadataFileURL: URL(fileURLWithPath: ""),   // Dummy URL
            scanDuration: 320.0,
            numberOfImages: 120,
            fileSize: 5000000,
            dimensions: ModelDimensions(width: 1.2, height: 0.8, depth: 0.5),
            qualityScore: 0.85,
            detailLevel: .full,
            hasLiDARData: true
        )
        
        NavigationView {
            ModelPreviewView(model: model)
                .environmentObject(FileStorageService.shared)
        }
    }
} 