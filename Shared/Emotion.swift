// Shared domain code: copied unchanged from Part A (PartA_iOS/MindBloom/Domain/Emotion.swift)
// so both prototypes use identical rules. A future version would move it into a Swift package.
import Foundation

/// The nine feelings a student can choose during a mood check-in.
///
/// Each emotion carries a *valence* from -2 (unpleasant) to +2 (pleasant).
/// The valence is what the app averages to describe trends. It is a simple,
/// transparent scale chosen for self-reflection, not a clinical measure.
enum Emotion: String, CaseIterable, Codable, Identifiable, Sendable {
    case joyful, grateful, calm
    case motivated, okay, tired
    case anxious, stressed, sad

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .joyful: "Joyful"
        case .grateful: "Grateful"
        case .calm: "Calm"
        case .motivated: "Motivated"
        case .okay: "Okay"
        case .tired: "Tired"
        case .anxious: "Anxious"
        case .stressed: "Stressed"
        case .sad: "Low"
        }
    }

    /// Pleasantness from -2 to +2.
    var valence: Int {
        switch self {
        case .joyful, .grateful: 2
        case .calm, .motivated: 1
        case .okay: 0
        case .tired, .anxious: -1
        case .stressed, .sad: -2
        }
    }

    /// Valence mapped onto a friendlier 1–5 "mood score" used in charts.
    var moodScore: Double { Double(3 + valence) }

    /// SF Symbol shown on the check-in tile.
    var symbolName: String {
        switch self {
        case .joyful: "sun.max.fill"
        case .grateful: "heart.fill"
        case .calm: "leaf.fill"
        case .motivated: "bolt.fill"
        case .okay: "circle.dashed"
        case .tired: "moon.zzz.fill"
        case .anxious: "wind"
        case .stressed: "cloud.bolt.fill"
        case .sad: "cloud.rain.fill"
        }
    }
}

/// Optional context a student can attach to a check-in ("what's influencing this?").
enum MoodFactor: String, CaseIterable, Codable, Identifiable, Sendable {
    case study, exams, sleep, friends, family, exercise, health, money, rest

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .study: "Study"
        case .exams: "Exams"
        case .sleep: "Sleep"
        case .friends: "Friends"
        case .family: "Family"
        case .exercise: "Movement"
        case .health: "Health"
        case .money: "Money"
        case .rest: "Downtime"
        }
    }

    var symbolName: String {
        switch self {
        case .study: "book.closed"
        case .exams: "pencil.and.list.clipboard"
        case .sleep: "bed.double"
        case .friends: "person.2"
        case .family: "house"
        case .exercise: "figure.walk"
        case .health: "cross.case"
        case .money: "creditcard"
        case .rest: "cup.and.saucer"
        }
    }
}
