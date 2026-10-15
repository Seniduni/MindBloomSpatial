import SwiftUI
import SwiftData

/// MIND BLOOM Spatial — a visionOS companion prototype.
///
/// Three scenes, each using a different spatial capability:
/// 1. `main`      — a regular window: check in with floating mood orbs, tend habits, launch the other scenes.
/// 2. `garden`    — a volumetric window: a 3D wellness garden built with RealityKit from your records.
/// 3. `breathing` — an immersive space: a paced breathing orb in a calm, dimmable environment.
@main
@MainActor
struct MindBloomSpatialApp: App {
    @State private var appModel = AppModel()
    @State private var breathingImmersion: ImmersionStyle = .mixed
    private let container: ModelContainer = SpatialStore.makeContainer()

    var body: some Scene {
        WindowGroup(id: AppModel.mainWindowID) {
            ContentView()
                .environment(appModel)
        }
        .defaultSize(width: 980, height: 720)
        .modelContainer(container)

        WindowGroup(id: AppModel.gardenWindowID) {
            GardenVolumeView()
                .environment(appModel)
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 0.9, height: 0.6, depth: 0.9, in: .meters)
        .modelContainer(container)

        ImmersiveSpace(id: AppModel.breathingSpaceID) {
            BreathingSpaceView()
                .environment(appModel)
                .onAppear { appModel.immersiveState = .open }
                .onDisappear { appModel.immersiveState = .closed }
        }
        .immersionStyle(selection: $breathingImmersion, in: .mixed, .progressive, .full)
        .modelContainer(container)
    }
}
