import SwiftUI
import RealityKit
import UniformTypeIdentifiers

@main
struct USDZViewerApp: App {
    var body: some SwiftUI.Scene {
        WindowGroup {
            ContentView()
        }
        
        ImmersiveSpace(id: "ImmersiveSpace") {
            ImmersiveView()
        }
    }
}

struct ContentView: View {
    @State private var selectedFileURL: URL?
    @State private var isFileImporterPresented = false
    @State private var isImmersiveSpacePresented = false
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                if let fileURL = selectedFileURL {
                    // Display the 3D model
                    Model3D(url: fileURL) { model in
                        model
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        ProgressView("Loading 3D Model...")
                            .frame(width: 200, height: 200)
                    }
                    .frame(width: 400, height: 400)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    
                    VStack(spacing: 16) {
                        Text("USDZ Model Loaded")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Text(fileURL.lastPathComponent)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 20) {
                            Button("Import New File") {
                                isFileImporterPresented = true
                            }
                            .buttonStyle(.bordered)
                            
                            Button("View in Immersive Space") {
                                Task {
                                    await openImmersiveSpace(id: "ImmersiveSpace")
                                    isImmersiveSpacePresented = true
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        
                        if isImmersiveSpacePresented {
                            Button("Exit Immersive Space") {
                                Task {
                                    await dismissImmersiveSpace()
                                    isImmersiveSpacePresented = false
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                } else {
                    // File import interface
                    VStack(spacing: 20) {
                        Image(systemName: "cube.transparent")
                            .font(.system(size: 80))
                            .foregroundColor(.secondary)
                        
                        Text("Import USDZ File")
                            .font(.title)
                            .fontWeight(.medium)
                        
                        Text("Select a USDZ file to view in 3D")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        Button("Choose File") {
                            isFileImporterPresented = true
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                }
            }
            .padding(40)
            .navigationTitle("USDZ Viewer")
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.usd, .usdz],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    selectedFileURL = url
                }
            case .failure(let error):
                print("File import error: \(error)")
            }
        }
    }
}

struct ImmersiveView: View {
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    
    var body: some View {
        RealityView { content in
            // Create immersive 3D environment
            let anchor = AnchorEntity(.head)
            
            // Add some ambient lighting
            let lightEntity = Entity()
            let light = DirectionalLightComponent(
                color: .white,
                intensity: 1000
            )
            lightEntity.components.set(light)
            lightEntity.position = [0, 2, 0]
            anchor.addChild(lightEntity)
            
            // Load and display the USDZ model if available
            if let modelURL = UserDefaults.standard.url(forKey: "selectedUSDZFile") {
                Task {
                    do {
                        let modelEntity = try await Entity(contentsOf: modelURL)
                        modelEntity.position = [0, 0, -2] // Position in front of user
                        modelEntity.scale = [0.5, 0.5, 0.5] // Scale down if needed
                        
                        // Add rotation animation for visionOS 2
                        let rotationAnimation = FromToByAnimation<Transform>(
                            name: "rotation",
                            from: .init(scale: modelEntity.scale, rotation: modelEntity.orientation),
                            to: .init(scale: modelEntity.scale, rotation: simd_quatf(angle: .pi * 2, axis: [0, 1, 0])),
                            duration: 10,
                            timing: .linear,
                        //    repeatMode: .repeating
                        )
                        
                        if let animationResource = try? AnimationResource.generate(with: rotationAnimation) {
                            modelEntity.playAnimation(animationResource)
                        }
                        
                        anchor.addChild(modelEntity)
                    } catch {
                        print("Error loading model in immersive space: \(error)")
                    }
                }
            }
            
            content.add(anchor)
        }
        .gesture(
            TapGesture()
                .onEnded { _ in
                    Task {
                        await dismissImmersiveSpace()
                    }
                }
        )
        .onAppear {
            // Store the selected file URL for use in immersive space
            // In a real app, you'd want a more robust state management solution
        }
    }
}

// Extension to support USDZ file types
extension UTType {
    static let usdz = UTType(filenameExtension: "usdz")!
    static let usd = UTType(filenameExtension: "usd")!
}

#Preview {
    ContentView()
}
