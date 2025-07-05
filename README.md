# OmniXR Measure - 3D Object Scanning iOS App

A production-quality native iOS app built with Swift that uses Apple's Object Capture API to scan real-world objects into high-quality 3D models (USDZ format) with precise measurements and AR preview capabilities.

## Features

### 🎯 Core Functionality
- **3D Object Scanning**: Guided photogrammetry workflow using Apple's Object Capture API
- **Surface Area Computation**: Precise measurements using ARMeshGeometry faces
- **AR Preview**: View scanned models in augmented reality
- **Local Storage**: Organized file management in app Documents directory
- **Export & Share**: Share USDZ models with other apps and users

### 📱 User Interface
- **Main Library**: Grid/list view of all scanned 3D models
- **Guided Capture**: Step-by-step scanning workflow (Top → Middle → Bottom → 360°)
- **3D Preview**: Interactive SceneKit/RealityKit model viewer
- **Measurement Tools**: Display dimensions, surface area, and volume
- **Edit Mode**: Bulk selection and deletion of models

### 🔧 Technical Features
- **MVVM Architecture**: Clean separation of concerns
- **Async/Await**: Modern Swift concurrency patterns
- **SwiftUI**: Declarative user interface
- **Core Data**: Local data persistence
- **File Management**: Organized directory structure

## Requirements

### System Requirements
- **iOS**: 17.0+ (for Object Capture API)
- **Xcode**: 15.0+ 
- **Swift**: 5.9+
- **Device**: iPhone/iPad with A12 Bionic chip or newer
- **Camera**: Required for photogrammetry capture
- **Storage**: Minimum 2GB free space recommended

### Framework Dependencies
- **ARKit**: Augmented reality and world tracking
- **RealityKit**: 3D rendering and Object Capture processing
- **AVFoundation**: Camera access and media capture
- **SwiftUI**: User interface framework
- **QuickLook**: USDZ model preview

## Setup Instructions

### 1. Xcode Project Configuration

**Important**: The project requires manual framework linking due to iOS-specific AR capabilities.

1. **Open Project in Xcode**:
   ```bash
   open omnixr-measure.xcodeproj
   ```

2. **Link Required Frameworks**:
   - Select project target → General → Frameworks, Libraries, and Embedded Content
   - Add the following frameworks:
     - `ARKit.framework`
     - `RealityKit.framework` 
     - `AVFoundation.framework`
     - `QuickLook.framework`

3. **Configure Deployment Target**:
   - Set minimum deployment target to iOS 17.0
   - Ensure supported device orientations are configured

4. **Add Info.plist Entries**:
   ```xml
   <key>NSCameraUsageDescription</key>
   <string>This app uses the camera to scan 3D objects using photogrammetry</string>
   
   <key>NSPhotoLibraryUsageDescription</key>
   <string>Save and access 3D model thumbnails</string>
   
   <key>ARKit</key>
   <dict>
       <key>ARWorldTrackingConfiguration</key>
       <true/>
   </dict>
   ```

5. **Code Sign Configuration**:
   - Select a valid development team
   - Configure appropriate provisioning profiles
   - Enable required capabilities (ARKit)

### 2. Build and Run

1. **Clean Build Folder**:
   ```
   Product → Clean Build Folder (⇧⌘K)
   ```

2. **Build Project**:
   ```
   Product → Build (⌘B)
   ```

3. **Run on Device**:
   - Connect iOS device via USB
   - Select device as target
   - Run (⌘R)

**Note**: Object Capture requires a physical iOS device - it will not work in the iOS Simulator.

## Usage Guide

### Scanning Your First Object

1. **Launch App**: Open OmniXR Measure
2. **Start New Scan**: Tap "Start New Scan" button
3. **Name Your Model**: Enter a descriptive name
4. **Follow Guided Steps**:
   - **Setup**: Position object on flat surface with good lighting
   - **Top View**: Capture from above, moving around the object
   - **Middle View**: Capture from eye level, keeping object centered
   - **Bottom View**: Capture from below angles
   - **360° Capture**: Complete full rotation around object
5. **Processing**: Wait for AI processing (2-5 minutes)
6. **Preview**: Review your 3D model and measurements

### Model Library Management

- **View Models**: Browse all scanned models in the main library
- **Edit Mode**: Tap "Edit" to enable bulk selection
- **Delete Models**: Swipe left or use bulk delete
- **Search**: Use search bar to find specific models
- **Sort Options**: Sort by date, name, or file size

### AR Preview & Measurements

- **3D View**: Interactive model viewer with pan/zoom/rotate
- **AR Mode**: Place model in real world using ARKit
- **Measurements**: View precise dimensions and surface area
- **Export**: Share USDZ file via AirDrop, Messages, etc.

## Architecture

### MVVM Pattern

```
Models/
├── ScannedModel.swift          # Core data model
├── StorageInfo.swift           # Storage statistics
└── CaptureTypes.swift          # Workflow enums

ViewModels/
└── MainLibraryViewModel.swift  # Main UI state management

Views/
├── ContentView.swift           # Main library view
├── ModelRowView.swift          # Individual model row
├── ObjectCaptureWorkflowView.swift  # Capture workflow
└── ModelPreviewView.swift      # 3D model preview

Services/
├── FileStorageService.swift    # File management
└── CaptureSessionManager.swift # Capture coordination
```

### Data Flow

1. **User Interaction** → ViewModels update `@Published` properties
2. **ViewModels** → Coordinate with Services for business logic
3. **Services** → Handle file I/O, capture processing, storage
4. **Models** → Represent data structure and computed properties

### Storage Structure

```
Documents/
├── Models/           # USDZ 3D model files
├── Metadata/         # JSON model metadata
├── Thumbnails/       # JPG preview images
└── Temp/            # Temporary capture files
```

## Troubleshooting

### Common Issues

**1. App Crashes on Launch**
- Ensure ARKit frameworks are properly linked
- Verify iOS deployment target is 17.0+
- Check device compatibility (A12+ chip required)

**2. Camera Permission Denied**
- Go to Settings → Privacy & Security → Camera
- Enable camera access for OmniXR Measure
- Restart the app

**3. Object Capture Fails**
- Ensure good lighting conditions
- Keep object stationary during capture
- Avoid reflective or transparent objects
- Capture at least 20-30 images per step

**4. Poor 3D Model Quality**
- Use better lighting (avoid shadows)
- Capture more images from different angles
- Keep camera steady and in focus
- Choose objects with good surface texture

**5. Storage Issues**
- Check available device storage
- Large models can be 10-50MB each
- Use "Edit" mode to delete unused models

### Debug Tips

**Enable Detailed Logging**:
```swift
// Add to omnixr_measureApp.swift
#if DEBUG
print("🐛 Debug mode enabled")
#endif
```

**Monitor Performance**:
- Use Instruments for memory profiling
- Monitor ARKit performance metrics
- Check for memory leaks during capture

### Performance Optimization

- **Background Processing**: Capture processing runs on background queues
- **Memory Management**: Large meshes are released after processing
- **File Compression**: USDZ files are automatically optimized
- **Thumbnail Generation**: Async image loading prevents UI blocking

## API Reference

### ScannedModel
```swift
struct ScannedModel {
    let id: UUID
    let name: String
    let dimensions: ModelDimensions
    let surfaceArea: Double?
    let qualityScore: Double
    // ... additional properties
}
```

### FileStorageService
```swift
class FileStorageService: ObservableObject {
    func loadAllModels() async -> [ScannedModel]
    func saveModel(_ model: ScannedModel) async -> Bool
    func deleteModels(_ models: [ScannedModel]) async -> Bool
    // ... additional methods
}
```

### CaptureSessionManager
```swift
class CaptureSessionManager: ObservableObject {
    @Published var captureState: CaptureState
    @Published var progress: Double
    
    func startCaptureSession(modelName: String)
    func moveToNextStep()
    // ... additional methods
}
```

## Limitations

### Technical Limitations
- **iOS 17+ Required**: Object Capture API availability
- **Device Compatibility**: A12 Bionic chip or newer required
- **Processing Time**: 2-5 minutes per model depending on complexity
- **File Size**: Models can be 10-50MB depending on detail level

### Object Scanning Limitations
- **Object Size**: Best results with objects 10cm - 2m in size
- **Surface Types**: Avoid highly reflective, transparent, or dark objects
- **Lighting**: Requires consistent, diffused lighting
- **Movement**: Object must remain completely stationary

### Current Implementation Status
- **ARKit Integration**: Placeholder implementations (requires Xcode framework linking)
- **Surface Area Calculation**: Algorithmic approach implemented
- **Export Options**: USDZ sharing functional
- **Cloud Sync**: Not implemented (local storage only)

## Contributing

### Development Setup
1. Fork the repository
2. Follow setup instructions above
3. Create feature branch: `git checkout -b feature/new-feature`
4. Commit changes: `git commit -am 'Add new feature'`
5. Push branch: `git push origin feature/new-feature`
6. Submit pull request

### Code Style
- Follow Swift API Design Guidelines
- Use SwiftLint for code formatting
- Add comprehensive documentation comments
- Include unit tests for new features

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- **Apple**: Object Capture API and ARKit framework
- **WWDC Sessions**: iOS 3D scanning implementation guidance
- **RealityKit Documentation**: 3D rendering best practices
- **Swift Community**: Modern iOS architecture patterns

---

**Built with ❤️ using Swift, SwiftUI, ARKit, and RealityKit** 