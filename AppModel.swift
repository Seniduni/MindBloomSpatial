import SwiftUI

/// App-wide state shared by all scenes.
@Observable
@MainActor
final class AppModel {
    static let mainWindowID = "main"
    static let gardenWindowID = "garden"
    static let breathingSpaceID = "breathing"

    enum ImmersiveState { case closed, inTransition, open }

    var immersiveState: ImmersiveState = .closed
    var breathingPattern: BreathingPattern = .longExhale
    var breathingMinutes = 3
    /// Set by the immersive space when a session ends, shown in the main window.
    var lastSessionSummary: String?
}

/// Opens or closes the immersive breathing space, guarding against double taps
/// while a transition is already in progress.
struct BreathingSpaceToggle: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    var body: some View {
        Button {
            Task { await toggle() }
        } label: {
            Label(appModel.immersiveState == .open ? "Leave breathing space" : "Enter breathing space",
                  systemImage: appModel.immersiveState == .open ? "xmark.circle" : "wind")
                .frame(minWidth: 240)
        }
        .controlSize(.extraLarge)
        .disabled(appModel.immersiveState == .inTransition)
    }

    private func toggle() async {
        switch appModel.immersiveState {
        case .open:
            appModel.immersiveState = .inTransition
            await dismissImmersiveSpace()
        case .closed:
            appModel.immersiveState = .inTransition
            switch await openImmersiveSpace(id: AppModel.breathingSpaceID) {
            case .opened:
                break   // `onAppear` in the space sets `.open`
            case .userCancelled, .error:
                appModel.immersiveState = .closed
            @unknown default:
                appModel.immersiveState = .closed
            }
        case .inTransition:
            break
        }
    }
}
