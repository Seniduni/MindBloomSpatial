import SwiftUI
import SwiftData
import RealityKit

/// Volumetric window: the 3D wellness garden. Look at an orb or plant and pinch
/// to see what it represents.
struct GardenVolumeView: View {
    @Query(sort: \OrbCheckIn.date, order: .reverse) private var orbs: [OrbCheckIn]
    @Query(sort: \GardenPlant.createdAt) private var plants: [GardenPlant]
    @Query private var calmSessions: [CalmSession]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var root = Entity()
    @State private var selectedName: String?

    /// Only the 12 most recent check-ins float in the garden, to keep it calm and readable.
    private var visibleOrbs: [OrbCheckIn] { Array(orbs.prefix(12)) }

    /// Changes whenever anything shown in the garden changes, triggering a rebuild.
    private var signature: String {
        let plantPart = plants.map { "\($0.name):\($0.completedDays.count):\($0.isTended(on: .now))" }.joined(separator: "|")
        let orbPart = visibleOrbs.map { "\($0.emotionRaw)\($0.intensity)\($0.date.timeIntervalSince1970)" }.joined()
        return "\(plantPart)#\(orbPart)#\(calmSessions.count)#\(reduceMotion)"
    }

    var body: some View {
        RealityView { content, attachments in
            content.add(root)
            rebuild()
            if let label = attachments.entity(for: "label") {
                label.isEnabled = false
                content.add(label)
            }
        } update: { _, attachments in
            guard let label = attachments.entity(for: "label") else { return }
            if let name = selectedName, let target = root.findEntity(named: name) {
                label.setPosition(target.position(relativeTo: nil) + SIMD3<Float>(0, 0.08, 0), relativeTo: nil)
                label.isEnabled = true
            } else {
                label.isEnabled = false
            }
        } attachments: {
            Attachment(id: "label") {
                Text(labelText)
                    .font(.title3)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .glassBackgroundEffect()
            }
        }
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    selectedName = (selectedName == value.entity.name) ? nil : value.entity.name
                }
        )
        .onChange(of: signature) { rebuild() }
        .ornament(attachmentAnchor: .scene(.bottom)) {
            HStack(spacing: 20) {
                Label("\(visibleOrbs.count) mood orbs", systemImage: "circle.fill")
                Label("\(plants.count) plants", systemImage: "leaf.fill")
                Label("\(calmSessions.count) fireflies", systemImage: "sparkle")
            }
            .font(.callout)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .glassBackgroundEffect()
            .accessibilityElement(children: .combine)
        }
        .accessibilityLabel("Wellness garden with \(plants.count) plants and \(visibleOrbs.count) mood orbs")
    }

    private var labelText: String {
        guard let name = selectedName else { return "" }
        if name.hasPrefix("plant:") {
            let plantName = String(name.dropFirst("plant:".count))
            let days = plants.first { $0.name == plantName }?.completedDays.count ?? 0
            return "\(plantName) · tended \(days) days"
        }
        if name.hasPrefix("orb:"), let index = Int(name.dropFirst("orb:".count)), visibleOrbs.indices.contains(index) {
            let orb = visibleOrbs[index]
            return "\(orb.emotion.displayName) · \(orb.intensity)/5 · \(orb.date.formatted(.dateTime.weekday().hour()))"
        }
        return ""
    }

    private func rebuild() {
        let plantSpecs = plants.map {
            GardenBuilder.PlantSpec(name: $0.name, color: $0.color.uiColor, growth: $0.growth, tendedToday: $0.isTended(on: .now))
        }
        let orbSpecs = visibleOrbs.enumerated().map { index, orb in
            GardenBuilder.OrbSpec(id: "orb:\(index)", color: orb.emotion.uiColor, intensity: orb.intensity)
        }
        GardenBuilder.rebuild(root, plants: plantSpecs, orbs: orbSpecs, fireflies: calmSessions.count, animate: !reduceMotion)
        if selectedName != nil { selectedName = nil }
    }
}
