// Shared domain code: copied unchanged from Part A (PartA_iOS/MindBloom/Domain/BreathingPattern.swift)
// so both prototypes use identical rules. A future version would move it into a Swift package.
import Foundation

enum BreathPhaseKind: String, Codable, Sendable {
    case inhale, holdIn, exhale, holdOut

    var instruction: String {
        switch self {
        case .inhale: "Breathe in"
        case .holdIn: "Hold"
        case .exhale: "Breathe out"
        case .holdOut: "Rest"
        }
    }
}

struct BreathPhase: Equatable, Sendable {
    let kind: BreathPhaseKind
    let seconds: Double
}

/// Where a breathing session is at a given moment. Pure output of `BreathingPattern.progress`.
struct BreathingProgress: Equatable, Sendable {
    let phase: BreathPhaseKind
    /// 0…1 through the current phase.
    let phaseFraction: Double
    let secondsLeftInPhase: Double
    let completedCycles: Int
    /// Index of the phase within the cycle; changes even when two consecutive phases share a kind.
    let phaseIndex: Int
}

/// Paced-breathing rhythms offered in the app. These are general relaxation
/// exercises, described without health claims.
enum BreathingPattern: String, CaseIterable, Codable, Identifiable, Sendable {
    case balanced, box, longExhale

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .balanced: "Balanced"
        case .box: "Box"
        case .longExhale: "Long exhale"
        }
    }

    var summary: String {
        switch self {
        case .balanced: "Even 5-second breaths in and out. A gentle place to start."
        case .box: "In, hold, out, hold — 4 seconds each. Steady and structured."
        case .longExhale: "In for 4, out for 6. Many people find a longer out-breath settling."
        }
    }

    var phases: [BreathPhase] {
        switch self {
        case .balanced:
            [BreathPhase(kind: .inhale, seconds: 5), BreathPhase(kind: .exhale, seconds: 5)]
        case .box:
            [BreathPhase(kind: .inhale, seconds: 4), BreathPhase(kind: .holdIn, seconds: 4),
             BreathPhase(kind: .exhale, seconds: 4), BreathPhase(kind: .holdOut, seconds: 4)]
        case .longExhale:
            [BreathPhase(kind: .inhale, seconds: 4), BreathPhase(kind: .exhale, seconds: 6)]
        }
    }

    var cycleDuration: Double { phases.reduce(0) { $0 + $1.seconds } }

    /// Session lengths offered on the breathing screen, in minutes.
    static let durationOptions = [1, 3, 5]
    /// Sessions ended early are saved only after this many seconds.
    static let minimumRecordableSeconds: Double = 30

    func progress(atElapsed elapsed: TimeInterval) -> BreathingProgress {
        let safeElapsed = max(0, elapsed)
        let cycles = Int(safeElapsed / cycleDuration)
        var offset = safeElapsed - Double(cycles) * cycleDuration
        for (index, phase) in phases.enumerated() {
            if offset < phase.seconds {
                return BreathingProgress(phase: phase.kind,
                                         phaseFraction: offset / phase.seconds,
                                         secondsLeftInPhase: phase.seconds - offset,
                                         completedCycles: cycles,
                                         phaseIndex: index)
            }
            offset -= phase.seconds
        }
        // Floating-point edge: exactly at the cycle boundary.
        return BreathingProgress(phase: phases[0].kind, phaseFraction: 0,
                                 secondsLeftInPhase: phases[0].seconds,
                                 completedCycles: cycles + 1, phaseIndex: 0)
    }

    /// Visual size of the breathing orb (0.55 = resting, 1.0 = full breath).
    static func orbScale(for progress: BreathingProgress) -> Double {
        let low = 0.55, high = 1.0
        let eased = (1 - cos(progress.phaseFraction * .pi)) / 2   // ease-in-out
        switch progress.phase {
        case .inhale: return low + (high - low) * eased
        case .holdIn: return high
        case .exhale: return high - (high - low) * eased
        case .holdOut: return low
        }
    }
}
