import SwiftUI
import SwiftData

/// Main window: release a mood orb, tend habit plants, and open the garden
/// volume or the immersive breathing space.
struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \OrbCheckIn.date, order: .reverse) private var orbs: [OrbCheckIn]
    @Query(sort: \GardenPlant.createdAt) private var plants: [GardenPlant]
    @Query private var calmSessions: [CalmSession]

    @State private var selectedEmotion: Emotion?
    @State private var intensity = 3.0
    @State private var newPlantName = ""
    @State private var confirmation: String?

    private let orbColumns = Array(repeating: GridItem(.fixed(96), spacing: 16), count: 3)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    HStack(alignment: .top, spacing: 24) {
                        checkInPanel
                        gardenPanel
                    }
                    breathingPanel
                }
                .padding(32)
            }
            .navigationTitle("MIND BLOOM Spatial")
        }
        .ornament(attachmentAnchor: .scene(.bottom)) {
            HStack(spacing: 16) {
                Button("Load sample garden", systemImage: "sparkles") {
                    try? SpatialStore.loadSampleGarden(into: modelContext)
                }
                Button("Remove sample garden", systemImage: "wand.and.rays.inverse") {
                    try? SpatialStore.removeSampleGarden(from: modelContext)
                }
            }
            .padding()
            .glassBackgroundEffect()
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your wellness garden")
                .font(.extraLargeTitle2)
            Text("Every check-in becomes a floating orb, every habit a plant, every breathing session a firefly. Open the garden to see them in 3D.")
                .font(.title3)
                .foregroundStyle(.secondary)
            HStack(spacing: 24) {
                stat("\(orbs.count)", "mood orbs")
                stat("\(plants.count)", "plants")
                stat("\(calmSessions.count)", "fireflies")
            }
            .padding(.top, 8)
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading) {
            Text(value).font(.title.bold().monospacedDigit())
            Text(label).font(.callout).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Check-in

    private var checkInPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How do you feel?").font(.title2.bold())
            LazyVGrid(columns: orbColumns, spacing: 16) {
                ForEach(Emotion.allCases) { emotion in
                    MoodOrbButton(emotion: emotion, isSelected: selectedEmotion == emotion) {
                        selectedEmotion = emotion
                    }
                }
            }
            VStack(alignment: .leading) {
                Text("Intensity: \(Int(intensity)) of 5").font(.headline)
                Slider(value: $intensity, in: 1...5, step: 1)
                    .accessibilityValue("\(Int(intensity)) of 5")
            }
            Button {
                guard let emotion = selectedEmotion else { return }
                modelContext.insert(OrbCheckIn(emotion: emotion, intensity: Int(intensity)))
                try? modelContext.save()
                confirmation = "\(emotion.displayName) orb released into your garden."
                selectedEmotion = nil
            } label: {
                Label("Release orb", systemImage: "circle.hexagongrid.fill")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.extraLarge)
            .disabled(selectedEmotion == nil)
            if let confirmation {
                Text(confirmation).font(.callout).foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(width: 400)
        .glassBackgroundEffect()
    }

    // MARK: Garden & habits

    private var gardenPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Tend your plants").font(.title2.bold())
                Spacer()
                Button("Open garden", systemImage: "cube.transparent") {
                    openWindow(id: AppModel.gardenWindowID)
                }
            }
            if plants.isEmpty {
                Text("Add a habit below, or load the sample garden from the bar under this window.")
                    .foregroundStyle(.secondary)
            }
            ForEach(plants) { plant in
                let tended = plant.isTended(on: .now)
                HStack(spacing: 14) {
                    Circle().fill(plant.color.color).frame(width: 18, height: 18)
                    VStack(alignment: .leading) {
                        Text(plant.name).font(.headline)
                        Text("\(plant.completedDays.count) days tended").font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(tended ? "Tended today" : "Tend today",
                           systemImage: tended ? "checkmark.circle.fill" : "drop") {
                        plant.toggleToday()
                        try? modelContext.save()
                    }
                    .tint(tended ? Color(uiColor: SpatialTheme.teal) : nil)
                    .accessibilityLabel(tended ? "\(plant.name), tended today. Undo." : "Tend \(plant.name) today")
                }
                .padding(.vertical, 4)
            }
            HStack {
                TextField("New habit", text: $newPlantName)
                    .textFieldStyle(.roundedBorder)
                Button("Plant", systemImage: "plus") { addPlant() }
                    .disabled(newPlantName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassBackgroundEffect()
    }

    private func addPlant() {
        let name = newPlantName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 40,
              !plants.contains(where: { $0.name.lowercased() == name.lowercased() }) else {
            confirmation = "Choose a new, short habit name."
            return
        }
        let color = PlantColor.allCases[plants.count % PlantColor.allCases.count]
        modelContext.insert(GardenPlant(name: name, color: color))
        try? modelContext.save()
        newPlantName = ""
    }

    // MARK: Breathing

    private var breathingPanel: some View {
        @Bindable var appModel = appModel
        return VStack(alignment: .leading, spacing: 16) {
            Text("Breathing space").font(.title2.bold())
            Text("A paced breathing orb appears in front of you. Turn the Digital Crown to dim your surroundings. You can leave at any time.")
                .foregroundStyle(.secondary)
            HStack(spacing: 24) {
                Picker("Rhythm", selection: $appModel.breathingPattern) {
                    ForEach(BreathingPattern.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 420)
                .disabled(appModel.immersiveState != .closed)
                Picker("Minutes", selection: $appModel.breathingMinutes) {
                    ForEach(BreathingPattern.durationOptions, id: \.self) { Text("\($0) min").tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 260)
                .disabled(appModel.immersiveState != .closed)
                Spacer()
                BreathingSpaceToggle()
            }
            if let summary = appModel.lastSessionSummary {
                Label(summary, systemImage: "checkmark.seal").foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .glassBackgroundEffect()
    }
}

/// A large, glowing orb button for choosing a feeling (comfortable gaze + pinch target).
struct MoodOrbButton: View {
    let emotion: Emotion
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [.white.opacity(0.9), emotion.color], center: .topLeading,
                                             startRadius: 2, endRadius: 50))
                        .frame(width: 64, height: 64)
                        .shadow(color: emotion.color.opacity(0.6), radius: isSelected ? 18 : 6)
                    Image(systemName: emotion.symbolName)
                        .font(.title2)
                        .foregroundStyle(.white)
                }
                Text(emotion.displayName).font(.callout)
            }
            .frame(width: 96, height: 104)
            .scaleEffect(isSelected ? 1.08 : 1)
            .animation(.spring(duration: 0.3), value: isSelected)
        }
        .buttonStyle(.plain)
        .hoverEffect()
        .accessibilityLabel(emotion.displayName)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
