import Foundation
import SwiftData

/// A mood check-in made with a floating orb. Mirrors the iOS app's MoodEntry,
/// simplified for the prototype.
@Model
final class OrbCheckIn {
    var date: Date = Date.now
    var emotionRaw: String = Emotion.okay.rawValue
    var intensity: Int = 3
    var isSample: Bool = false

    init(date: Date = .now, emotion: Emotion, intensity: Int, isSample: Bool = false) {
        self.date = date
        self.emotionRaw = emotion.rawValue
        self.intensity = min(max(intensity, 1), 5)
        self.isSample = isSample
    }

    var emotion: Emotion { Emotion(rawValue: emotionRaw) ?? .okay }
}

/// A habit, shown as a plant. Each completed day makes it a little taller.
@Model
final class GardenPlant {
    var name: String = ""
    var colorKey: String = PlantColor.teal.rawValue
    var createdAt: Date = Date.now
    /// Start-of-day dates on which the habit was tended.
    var completedDays: [Date] = []
    var isSample: Bool = false

    init(name: String, color: PlantColor, completedDays: [Date] = [], isSample: Bool = false) {
        self.name = name
        self.colorKey = color.rawValue
        self.completedDays = completedDays
        self.isSample = isSample
    }

    var color: PlantColor { PlantColor(rawValue: colorKey) ?? .teal }

    func isTended(on date: Date, calendar: Calendar = .current) -> Bool {
        completedDays.contains { calendar.isDate($0, inSameDayAs: date) }
    }

    /// Adds or removes today's completion.
    func toggleToday(calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: .now)
        if isTended(on: today, calendar: calendar) {
            completedDays.removeAll { calendar.isDate($0, inSameDayAs: today) }
        } else {
            completedDays.append(today)
        }
    }

    /// 0…1 growth used for stem height: grows with completions, levelling off at 14.
    var growth: Double { min(1, Double(completedDays.count) / 14) }
}

/// A finished breathing session — appears as a firefly in the garden.
@Model
final class CalmSession {
    var date: Date = Date.now
    var seconds: Int = 0
    var patternRaw: String = BreathingPattern.longExhale.rawValue

    init(date: Date = .now, seconds: Int, pattern: BreathingPattern) {
        self.date = date
        self.seconds = seconds
        self.patternRaw = pattern.rawValue
    }
}

enum PlantColor: String, CaseIterable, Codable {
    case teal, mint, lavender, sky, sun, peach
}

enum SpatialStore {
    static func makeContainer() -> ModelContainer {
        let schema = Schema([OrbCheckIn.self, GardenPlant.self, CalmSession.self])
        do {
            return try ModelContainer(for: schema,
                                      configurations: [ModelConfiguration("MindBloomSpatial", schema: schema,
                                                                          cloudKitDatabase: .none)])
        } catch {
            // Prototype fallback: keep running with an in-memory store.
            return try! ModelContainer(for: schema,
                                       configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true,
                                                                           cloudKitDatabase: .none)])
        }
    }

    /// Seeds a small, deterministic garden so the prototype can be demonstrated immediately.
    @MainActor
    static func loadSampleGarden(into context: ModelContext, calendar: Calendar = .current) throws {
        try removeSampleGarden(from: context)
        let today = calendar.startOfDay(for: .now)
        func day(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: -offset, to: today) ?? today }

        let plants: [(String, PlantColor, [Int])] = [
            ("Drink water", .teal, [1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12]),
            ("Move for 20 minutes", .mint, [1, 3, 4, 7, 9, 12]),
            ("Lights out by 11:30", .lavender, [2, 3, 6, 7]),
            ("Phone-free study", .sky, [1, 2, 4, 5, 6, 9, 10, 13])
        ]
        for plant in plants {
            context.insert(GardenPlant(name: plant.0, color: plant.1, completedDays: plant.2.map(day), isSample: true))
        }
        let moods: [(Int, Emotion, Int)] = [(1, .calm, 3), (1, .motivated, 4), (2, .anxious, 3), (3, .tired, 2),
                                            (4, .grateful, 4), (5, .stressed, 4), (6, .okay, 3), (7, .joyful, 5)]
        for mood in moods {
            let date = calendar.date(byAdding: .hour, value: 9, to: day(mood.0)) ?? day(mood.0)
            context.insert(OrbCheckIn(date: date, emotion: mood.1, intensity: mood.2, isSample: true))
        }
        try context.save()
    }

    @MainActor
    static func removeSampleGarden(from context: ModelContext) throws {
        for plant in try context.fetch(FetchDescriptor<GardenPlant>()) where plant.isSample { context.delete(plant) }
        for orb in try context.fetch(FetchDescriptor<OrbCheckIn>()) where orb.isSample { context.delete(orb) }
        try context.save()
    }
}
