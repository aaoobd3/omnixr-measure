//
//  ContentView.swift
//  omnixr-measure
//
//  Created by phones luxury on 02/07/2025.
//

import SwiftUI
import RealityKit
import ARKit

/// Main Library View - Shows all previously scanned 3D models
/// Implements the "My 3D Models" functionality with MVVM architecture
struct ContentView: View {
    
    @EnvironmentObject private var fileStorageService: FileStorageService
    @EnvironmentObject private var captureSessionManager: CaptureSessionManager
    @StateObject private var viewModel = MainLibraryViewModel()
    
    @State private var showingCaptureWorkflow = false
    @State private var isEditing = false
    @State private var selectedModelsForDeletion: Set<UUID> = []
    @State private var selectedModelForNavigation: UUID?
    @State private var searchText = ""
    
    // MARK: - Computed Properties
    
    private var filteredModels: [ScannedModel] {
        viewModel.filteredModels(searchText: searchText)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with title and controls
                headerView
                
                // Models list or empty state
                if viewModel.models.isEmpty {
                    emptyStateView
                } else {
                    modelsListView
                }
            }
            .navigationTitle("My 3D Models")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !viewModel.models.isEmpty {
                        Button(isEditing ? "Done" : "Edit") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isEditing.toggle()
                                if !isEditing {
                                    selectedModelsForDeletion.removeAll()
                                }
                            }
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCaptureWorkflow = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("New Scan")
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingCaptureWorkflow, onDismiss: {
                // Refresh library when capture workflow is dismissed
                // This ensures new models appear immediately
                Task {
                    await viewModel.loadModels(from: fileStorageService)
                }
            }) {
                ObjectCaptureWorkflowView()
                    .environmentObject(fileStorageService)
                    .environmentObject(captureSessionManager)
            }

            .onAppear {
                Task {
                    await viewModel.loadModels(from: fileStorageService)
                }
            }
            .refreshable {
                Task {
                    await viewModel.loadModels(from: fileStorageService)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle()) // Force stack style on all devices
        .searchable(text: $searchText, prompt: "Search models...")
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "cube.transparent")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("3D Model Library")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("\(viewModel.models.count) model\(viewModel.models.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Storage info and cleanup button
                VStack(alignment: .trailing, spacing: 2) {
                    if let storageInfo = viewModel.storageInfo {
                        Text("\(storageInfo.formattedSize)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("Used")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    // Show cleanup button if there are missing files
                    let missingFilesCount = viewModel.models.filter { !$0.filesExist() }.count
                    if missingFilesCount > 0 {
                        Button("Clean (\(missingFilesCount))") {
                            Task {
                                await cleanupLibrary()
                            }
                        }
                        .font(.caption2)
                        .foregroundColor(.orange)
                    }
                }
            }
            .padding(.horizontal)
            
            // Bulk delete controls
            if isEditing && !selectedModelsForDeletion.isEmpty {
                HStack {
                    Button("Delete Selected (\(selectedModelsForDeletion.count))") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            deleteSelectedModels()
                        }
                    }
                    .foregroundColor(.red)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                    
                    Spacer()
                    
                    Button("Select All") {
                        selectedModelsForDeletion = Set(viewModel.models.map { $0.id })
                    }
                    .foregroundColor(.blue)
                }
                .padding(.horizontal)
                .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(.vertical, 8)
        .background(Color(UIColor.systemBackground))
    }
    
    // MARK: - Models List View
    
    private var modelsListView: some View {
        List {
            ForEach(filteredModels) { model in
                NavigationLink(
                    destination: ModelPreviewView(model: model).environmentObject(fileStorageService),
                    tag: model.id,
                    selection: $selectedModelForNavigation
                ) {
                    ModelRowView(
                        model: model,
                        isEditing: isEditing,
                        isSelected: selectedModelsForDeletion.contains(model.id)
                    ) { selectedModel in
                        if isEditing {
                            toggleModelSelection(model)
                        } else {
                            selectedModelForNavigation = model.id
                        }
                    }
                }
                .disabled(isEditing)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            .onDelete(perform: isEditing ? nil : deleteModels)
        }
        .listStyle(.plain)
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "cube.transparent")
                .font(.system(size: 64))
                .foregroundColor(.blue.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("No 3D Models Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Start by scanning your first object\nwith our guided capture workflow")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button {
                showingCaptureWorkflow = true
            } label: {
                HStack {
                    Image(systemName: "camera.fill")
                    Text("Start First Scan")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(12)
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Helper Methods
    
    private func toggleModelSelection(_ model: ScannedModel) {
        if selectedModelsForDeletion.contains(model.id) {
            selectedModelsForDeletion.remove(model.id)
        } else {
            selectedModelsForDeletion.insert(model.id)
        }
    }
    
    private func deleteModels(at offsets: IndexSet) {
        let modelsToDelete = offsets.map { viewModel.models[$0] }
        Task {
            await viewModel.deleteModels(modelsToDelete, from: fileStorageService)
        }
    }
    
    private func deleteSelectedModels() {
        let modelsToDelete = viewModel.models.filter { selectedModelsForDeletion.contains($0.id) }
        
        Task {
            await viewModel.deleteModels(modelsToDelete, from: fileStorageService)
        }
        
        selectedModelsForDeletion.removeAll()
        isEditing = false
    }
    
    private func cleanupLibrary() async {
        let success = await fileStorageService.cleanupMissingFiles()
        if success {
            await viewModel.loadModels(from: fileStorageService)
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(FileStorageService.shared)
        .environmentObject(CaptureSessionManager())
}
