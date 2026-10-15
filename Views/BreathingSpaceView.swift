import SwiftUI
import SwiftData
import RealityKit
import UIKit

/// Immersive breathing space.
///
/// Comfort choices: the orb is fixed in place about 1.4 m ahead at roughly eye
/// level; nothing moves around the person or the camera; scale changes are slow
/// (4–6 s); and the control panel with "End" and "Leave" is always in view.
/// With Reduce Motion on, the orb changes colour instead of size.
struct BreathingSpaceView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var orb = ModelEntity()
    @State private var startDate: Date?
    @State private var instruction = "Get comfortable"
    @State private var secondsLeft = 0
    @State private var summary: String?

    private static let restScale: Float = 0.55
    private var totalSeconds: Int { appModel.breathingMinutes * 60 }

    var body: some View {
        RealityView { content, attachments in
            let stage = Entity()
            stage.position = [0, 1.35, -1.4]
            content.add(stage)

            orb.model = ModelComponent(mesh: .generateSphere(radius: 0.22),
                                       materials: [SimpleMaterial(color: SpatialTheme.teal.withAlphaComponent(0.9),
                                                                  roughness: 0.2, isMetallic: false)])
            orb.scale = SIMD3(repeating: Self.restScale)
            stage.addChild(orb)

            let halo = ModelEntity(mesh: .generateSphere(radius: 0.36),
                                   materials: [UnlitMaterial(color: SpatialTheme.lavender)])
            halo.components.set(OpacityComponent(opacity: 0.12))
            stage.addChild(halo)

            // A still ring of soft "petals" frames the orb without moving.
            for index in 0..<10 {
                let angle = Float(index) / 10 * .pi * 2
                let petal = ModelEntity(mesh: .generateSphere(radius: 0.03),
                                        materials: [UnlitMaterial(color: index.isMultiple(of: 2) ? SpatialTheme.mint : SpatialTheme.lavender)])
                petal.position = [cos(angle) * 0.5, sin(angle) * 0.5, 0]
                petal.components.set(OpacityComponent(opacity: 0.6))
                stage.addChild(petal)
            }

            if let panel = attachments.entity(for: "panel") {
                panel.position = [0, -0.55, 0.15]
                stage.addChild(panel)
            }
        } attachments: {
            Attachment(id: "panel") { controlPanel }
        }
        .task(id: startDate) { await runSession() }
        .onDisappear {
            if startDate != nil { finish(completed: false) }
        }
    }

    // MARK: Controls

    private var controlPanel: some View {
        VStack(spacing: 18) {
            Text(appModel.breathingPattern.displayName)
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(instruction)
                .font(.extraLargeTitle2)
                .contentTransition(.opacity)
                .accessibilityAddTraits(.updatesFrequently)
            if startDate != nil {
                Text("\(secondsLeft / 60):\(String(format: "%02d", secondsLeft % 60)) left")
                    .font(.title3.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else if let summary {
                Text(summary).font(.title3).foregroundStyle(.secondary)
            }
            HStack(spacing: 20) {
                if startDate == nil {
                    Button(summary == nil ? "Begin" : "Breathe again", systemImage: "play.fill") {
                        summary = nil
                        startDate = .now
                    }
                } else {
                    Button("End session", systemImage: "stop.fill") { finish(completed: false) }
                }
                Button("Leave space", systemImage: "xmark") {
                    if startDate != nil { finish(completed: false) }
                    Task { await dismissImmersiveSpace() }
                }
            }
            .controlSize(.extraLarge)
        }
        .padding(32)
        .frame(width: 560)
        .glassBackgroundEffect()
    }

    // MARK: Session

    private func runSession() async {
        guard let start = startDate else { return }
        let pattern = appModel.breathingPattern
        var lastKey = -1
        while !Task.isCancelled {
            let elapsed = Date.now.timeIntervalSince(start)
            secondsLeft = max(0, totalSeconds - Int(elapsed))
            if elapsed >= Double(totalSeconds) {
                finish(completed: true)
                return
            }
            let progress = pattern.progress(atElapsed: elapsed)
            let key = progress.completedCycles * 10 + progress.phaseIndex
            if key != lastKey {
                lastKey = key
                instruction = progress.phase.instruction
                animateOrb(for: progress.phase, duration: progress.secondsLeftInPhase)
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    private func animateOrb(for phase: BreathPhaseKind, duration: Double) {
        if reduceMotion {
            let color: UIColor = switch phase {
            case .inhale: SpatialTheme.teal
            case .exhale: SpatialTheme.lavender
            case .holdIn, .holdOut: SpatialTheme.sky
            }
            orb.model?.materials = [SimpleMaterial(color: color.withAlphaComponent(0.9), roughness: 0.2, isMetallic: false)]
            return
        }
        let target: Float
        switch phase {
        case .inhale: target = 1.0
        case .exhale: target = Self.restScale
        case .holdIn, .holdOut: return   // hold the current size
        }
        var transform = orb.transform
        transform.scale = SIMD3(repeating: target)
        orb.move(to: transform, relativeTo: orb.parent, duration: duration, timingFunction: .easeInOut)
    }

    private func finish(completed: Bool) {
        guard let start = startDate else { return }
        let seconds = min(Int(Date.now.timeIntervalSince(start)), totalSeconds)
        if completed || seconds >= Int(BreathingPattern.minimumRecordableSeconds) {
            modelContext.insert(CalmSession(date: start, seconds: seconds, pattern: appModel.breathingPattern))
            try? modelContext.save()
        }
        startDate = nil
        instruction = completed ? "Well done" : "Session ended"
        let text = "\(seconds / 60) min \(seconds % 60) s of paced breathing" + (completed ? " — a new firefly joins your garden." : ".")
        summary = text
        appModel.lastSessionSummary = text
        var rest = orb.transform
        rest.scale = SIMD3(repeating: Self.restScale)
        orb.move(to: rest, relativeTo: orb.parent, duration: reduceMotion ? 0 : 1.5, timingFunction: .easeInOut)
    }
}
